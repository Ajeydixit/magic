#include "perflib_preproc.cpp"
module rIterThetaParallel_mod
   use precision_mod
   use mem_alloc, only: bytes_allocated
   use rIteration_mod, only: rIteration_t

   use truncation, only: lm_max, lmP_max, l_max, lmP_max_dtB,      &
       &                 n_phi_maxStr, n_theta_maxStr, n_r_maxStr, &
       &                 lm_maxMag, l_axi, n_theta_max, n_phi_max, &
       &                 nrp, n_r_max, m_max, minc
   use blocking, only: nfs
   use logic, only: l_mag, l_conv, l_mag_kin, l_heat, l_ht, l_anel,  &
       &            l_mag_LF, l_conv_nl, l_mag_nl, l_b_nl_cmb,       &
       &            l_b_nl_icb, l_rot_ic, l_cond_ic, l_rot_ma,       &
       &            l_cond_ma, l_dtB, l_store_frame, l_movie_oc,     &
       &            l_TO, l_chemical_conv, l_TP_form, l_probe
   use radial_data,only: n_r_cmb, n_r_icb, nRstart, nRstop
   use radial_functions, only: or2, orho1
   use constants, only: zero
   use leg_helper_mod, only: leg_helper_t
   use nonlinear_lm_mod, only:nonlinear_lm_t
   use grid_space_arrays_mod, only: grid_space_arrays_t
   use TO_arrays_mod, only: TO_arrays_t
   use dtB_arrays_mod, only: dtB_arrays_t
   use torsional_oscillations, only: getTO, getTOnext, getTOfinish
   use graphOut_mod, only: graphOut_mpi
   use dtB_mod, only: get_dtBLM, get_dH_dtBLM
   use out_movie, only: store_movie_frame
   use outRot, only: get_lorentz_torque
   use courant_mod, only: courant
   use nonlinear_bcs, only: get_br_v_bcs, v_rigid_boundary
   use nl_special_calc
   use shtns
   use horizontal_data
   use fields, only: s_Rloc,ds_Rloc, z_Rloc,dz_Rloc, p_Rloc,dp_Rloc, &
       &             b_Rloc,db_Rloc,ddb_Rloc, aj_Rloc,dj_Rloc,       &
       &             w_Rloc,dw_Rloc,ddw_Rloc, xi_Rloc
   use physical_parameters, only: ktops, kbots, n_r_LCR
   use probe_mod
   use parallel_mod
   use MKL_DFTI
   use fft, only: fft_phi, m2phi_handle, phi2m_handle

   implicit none

   private

   type, public, extends(rIteration_t) :: rIterThetaParallel_t
      ! From rIterThetaBlocking_t
      integer :: sizeThetaB, nThetaBs
      type(leg_helper_t) :: leg_helper
      real(cp), allocatable :: BsLast(:,:,:), BpLast(:,:,:), BzLast(:,:,:)
      
      ! From rIterThetaBlocking_shtns_t
      integer :: nThreads
      type(grid_space_arrays_t) :: gsa
      type(TO_arrays_t) :: TO_arrays
      type(dtB_arrays_t) :: dtB_arrays
      type(nonlinear_lm_t) :: nl_lm
      real(cp) :: lorentz_torque_ic,lorentz_torque_ma
      
   contains
      ! From rIterThetaBlocking_t
      procedure :: allocate_common_arrays
      procedure :: deallocate_common_arrays
      procedure :: set_ThetaParallel
   
      ! From rIterThetaBlocking_shtns_t
      procedure :: initialize => initialize_rIterThetaParallel
      procedure :: finalize => finalize_rIterThetaParallel
      procedure :: do_iteration => do_iteration_ThetaParallel
      procedure :: getType => getThisType
      procedure :: transform_to_grid_space
      procedure :: transform_to_lm_space
   end type rIterThetaParallel_t

contains

subroutine allocate_common_arrays(this)

      class(rIterThetaParallel_t) :: this

      !----- Help arrays for Legendre transform calculated in legPrepG:
      !      Parallelizatio note: these are the R-distributed versions
      !      of the field scalars.
      call this%leg_helper%initialize(lm_max,lm_maxMag,l_max)

      allocate( this%BsLast(n_phi_maxStr,n_theta_maxStr,nRstart:nRstop) )
      allocate( this%BpLast(n_phi_maxStr,n_theta_maxStr,nRstart:nRstop) )
      allocate( this%BzLast(n_phi_maxStr,n_theta_maxStr,nRstart:nRstop) )
      bytes_allocated = bytes_allocated+ &
                       3*n_phi_maxStr*n_theta_maxStr*(nRstop-nRstart+1)*& 
                       SIZEOF_DEF_REAL

   end subroutine allocate_common_arrays
!-------------------------------------------------------------------------------
   subroutine deallocate_common_arrays(this)

      class(rIterThetaParallel_t) :: this

      call this%leg_helper%finalize()
      deallocate( this%BsLast)
      deallocate( this%BpLast)
      deallocate( this%BzLast)

   end subroutine deallocate_common_arrays
!-------------------------------------------------------------------------------
   subroutine set_ThetaParallel(this,nThetaBs,sizeThetaB)

      class(rIterThetaParallel_t) :: this
      integer,intent(in) :: nThetaBs, sizeThetaB

      this%nThetaBs = nThetaBs

      this%sizeThetaB = sizeThetaB

   end subroutine set_ThetaParallel
!-------------------------------------------------------------------------------
   function getThisType(this)

      class(rIterThetaParallel_t) :: this
      character(len=100) :: getThisType
      getThisType="rIterThetaParallel_t"

   end function getThisType
!------------------------------------------------------------------------------
   subroutine initialize_rIterThetaParallel(this)

      class(rIterThetaParallel_t) :: this

      call this%allocate_common_arrays()
      call this%gsa%initialize()
      if ( l_TO ) call this%TO_arrays%initialize()
      call this%dtB_arrays%initialize()
      call this%nl_lm%initialize(lmP_max)

   end subroutine initialize_rIterThetaParallel
!------------------------------------------------------------------------------
   subroutine finalize_rIterThetaParallel(this)

      class(rIterThetaParallel_t) :: this

      call this%deallocate_common_arrays()
      call this%gsa%finalize()
      if ( l_TO ) call this%TO_arrays%finalize()
      call this%dtB_arrays%finalize()
      call this%nl_lm%finalize()

   end subroutine finalize_rIterThetaParallel
!------------------------------------------------------------------------------
   subroutine do_iteration_ThetaParallel(this,nR,nBc,time,dt,dtLast, &
        &                 dsdt,dwdt,dzdt,dpdt,dxidt,dbdt,djdt,             &
        &                 dVxVhLM,dVxBhLM,dVSrLM,dVPrLM,dVXirLM,           &
        &                 br_vt_lm_cmb,br_vp_lm_cmb,                       &
        &                 br_vt_lm_icb,br_vp_lm_icb,                       &
        &                 lorentz_torque_ic, lorentz_torque_ma,            &
        &                 HelLMr,Hel2LMr,HelnaLMr,Helna2LMr,viscLMr,       &
        &                 uhLMr,duhLMr,gradsLMr,fconvLMr,fkinLMr,fviscLMr, &
        &                 fpoynLMr,fresLMr,EperpLMr,EparLMr,EperpaxiLMr,   &
        &                 EparaxiLMr)

      class(rIterThetaParallel_t) :: this
      integer,  intent(in) :: nR,nBc
      real(cp), intent(in) :: time,dt,dtLast

      complex(cp), intent(out) :: dwdt(:),dzdt(:),dpdt(:),dsdt(:),dVSrLM(:)
      complex(cp), intent(out) :: dxidt(:),dVPrLM(:),dVXirLM(:)
      complex(cp), intent(out) :: dbdt(:),djdt(:),dVxVhLM(:),dVxBhLM(:)
      !---- Output of nonlinear products for nonlinear
      !     magnetic boundary conditions (needed in s_updateB.f):
      complex(cp), intent(out) :: br_vt_lm_cmb(:) ! product br*vt at CMB
      complex(cp), intent(out) :: br_vp_lm_cmb(:) ! product br*vp at CMB
      complex(cp), intent(out) :: br_vt_lm_icb(:) ! product br*vt at ICB
      complex(cp), intent(out) :: br_vp_lm_icb(:) ! product br*vp at ICB
      real(cp),    intent(out) :: lorentz_torque_ma, lorentz_torque_ic
      real(cp),    intent(out) :: HelLMr(:),Hel2LMr(:),HelnaLMr(:),Helna2LMr(:)
      real(cp),    intent(out) :: viscLMr(:)
      real(cp),    intent(out) :: uhLMr(:), duhLMr(:) ,gradsLMr(:)
      real(cp),    intent(out) :: fconvLMr(:), fkinLMr(:), fviscLMr(:)
      real(cp),    intent(out) :: fpoynLMr(:), fresLMr(:)
      real(cp),    intent(out) :: EperpLMr(:), EparLMr(:), EperpaxiLMr(:), EparaxiLMr(:)

      integer :: l,lm
      logical :: lGraphHeader=.false.
      logical :: DEBUG_OUTPUT=.false.
      real(cp) :: c, lorentz_torques_ic

      this%nR=nR
      this%nBc=nBc
      this%isRadialBoundaryPoint=(nR == n_r_cmb).or.(nR == n_r_icb)

      if ( this%l_cour ) then
         this%dtrkc=1.e10_cp
         this%dthkc=1.e10_cp
      end if
      if ( this%lTOCalc ) then
         !------ Zero lm coeffs for first theta block:
         call this%TO_arrays%set_zero()
      end if

      call this%leg_helper%legPrepG(this%nR,this%nBc,this%lDeriv,this%lRmsCalc, &
           &                        this%lPressCalc,this%l_frame,this%lTOnext,  &
           &                        this%lTOnext2,this%lTOcalc)

      if (DEBUG_OUTPUT) then
         write(*,"(I3,A,I1,2(A,L1))") this%nR,": nBc = ", &
              & this%nBc,", lDeriv = ",this%lDeriv,", l_mag = ",l_mag
      end if


      this%lorentz_torque_ma = 0.0_cp
      this%lorentz_torque_ic = 0.0_cp
      lorentz_torques_ic = 0.0_cp
      c = 0.0_cp

      br_vt_lm_cmb=zero
      br_vp_lm_cmb=zero
      br_vt_lm_icb=zero
      br_vp_lm_icb=zero
      HelLMr=0.0_cp
      Hel2LMr=0.0_cp
      HelnaLMr=0.0_cp
      Helna2LMr=0.0_cp
      viscLMr=0.0_cp
      uhLMr = 0.0_cp
      duhLMr = 0.0_cp
      gradsLMr = 0.0_cp
      fconvLMr=0.0_cp
      fkinLMr=0.0_cp
      fviscLMr=0.0_cp
      fpoynLMr=0.0_cp
      fresLMr=0.0_cp
      EperpLMr=0.0_cp
      EparLMr=0.0_cp
      EperpaxiLMr=0.0_cp
      EparaxiLMr=0.0_cp

      call this%nl_lm%set_zero()

      call this%transform_to_grid_space(this%gsa)

      !--------- Calculation of nonlinear products in grid space:
      if ( (.not.this%isRadialBoundaryPoint) .or. this%lMagNlBc .or. &
            this%lRmsCalc ) then

         PERFON('get_nl')
         call this%gsa%get_nl_shtns(this%nR, this%nBc, this%lRmsCalc)
         PERFOFF

         call this%transform_to_lm_space(this%gsa, this%nl_lm)

      else if ( l_mag ) then
         do lm=1,lmP_max
            this%nl_lm%VxBtLM(lm)=0.0_cp
            this%nl_lm%VxBpLM(lm)=0.0_cp
         end do
      end if

      !---- Calculation of nonlinear products needed for conducting mantle or
      !     conducting inner core if free stress BCs are applied:
      !     input are brc,vtc,vpc in (theta,phi) space (plus omegaMA and ..)
      !     ouput are the products br_vt_lm_icb, br_vt_lm_cmb, br_vp_lm_icb,
      !     and br_vp_lm_cmb in lm-space, respectively the contribution
      !     to these products from the points theta(nThetaStart)-theta(nThetaStop)
      !     These products are used in get_b_nl_bcs.
      if ( this%nR == n_r_cmb .and. l_b_nl_cmb ) then
         call get_br_v_bcs(this%gsa%brc,this%gsa%vtc,               &
              &            this%gsa%vpc,this%leg_helper%omegaMA,    &
              &            or2(this%nR),orho1(this%nR), 1,          &
              &            this%sizeThetaB,br_vt_lm_cmb,br_vp_lm_cmb)
      else if ( this%nR == n_r_icb .and. l_b_nl_icb ) then
         call get_br_v_bcs(this%gsa%brc,this%gsa%vtc,               &
              &            this%gsa%vpc,this%leg_helper%omegaIC,    &
              &            or2(this%nR),orho1(this%nR), 1,          &
              &            this%sizeThetaB,br_vt_lm_icb,br_vp_lm_icb)
      end if
      !PERFOFF
      !--------- Calculate Lorentz torque on inner core:
      !          each call adds the contribution of the theta-block to
      !          lorentz_torque_ic
      if ( this%nR == n_r_icb .and. l_mag_LF .and. l_rot_ic .and. l_cond_ic  ) then
         lorentz_torques_ic=0.0_cp
         call get_lorentz_torque(lorentz_torques_ic,                &
              &                  1,this%sizeThetaB,                 &
              &                  this%gsa%brc,                      &
              &                  this%gsa%bpc,this%nR)
      end if

      !--------- Calculate Lorentz torque on mantle:
      !          note: this calculates a torque of a wrong sign.
      !          sign is reversed at the end of the theta blocking.
      if ( this%nR == n_r_cmb .and. l_mag_LF .and. l_rot_ma .and. l_cond_ma ) then
         call get_lorentz_torque(this%lorentz_torque_ma,   &
              &                  1 ,this%sizeThetaB,       &
              &                  this%gsa%brc,             &
              &                  this%gsa%bpc,this%nR)
      end if
      !PERFOFF

      !--------- Calculate courant condition parameters:
      if ( this%l_cour ) then
         !PRINT*,"Calling courant with this%nR=",this%nR
         call courant(this%nR,this%dtrkc,this%dthkc,this%gsa%vrc, &
              &       this%gsa%vtc,this%gsa%vpc,                  &
              &       this%gsa%brc,this%gsa%btc,                  &
              &       this%gsa%bpc,1 ,this%sizeThetaB)
      end if

      !--------- Since the fields are given at gridpoints here, this is a good
      !          point for graphical output:
      if ( this%l_graph ) then
            PERFON('graphout')
            call graphOut_mpi(time,this%nR,this%gsa%vrc,           &
                 &            this%gsa%vtc,this%gsa%vpc,           &
                 &            this%gsa%brc,this%gsa%btc,           &
                 &            this%gsa%bpc,this%gsa%sc,            &
                 &            this%gsa%pc,this%gsa%xic,            &
                 &            1 ,this%sizeThetaB,lGraphHeader)
            PERFOFF
      end if

      if ( this%l_probe_out ) then
         call probe_out(time,this%nR,this%gsa%vpc, 1,this%sizeThetaB)
      end if

      !--------- Helicity output:
      if ( this%lHelCalc ) then
         PERFON('hel_out')
         call get_helicity(this%gsa%vrc,this%gsa%vtc,          &
              &        this%gsa%vpc,this%gsa%cvrc,             &
              &        this%gsa%dvrdtc,                        &
              &        this%gsa%dvrdpc,                        &
              &        this%gsa%dvtdrc,                        &
              &        this%gsa%dvpdrc,HelLMr,Hel2LMr,         &
              &        HelnaLMr,Helna2LMr,this%nR,1 )
         PERFOFF
      end if

      !--------- Viscous heating:
      if ( this%lPowerCalc ) then
         PERFON('hel_out')
         call get_visc_heat(this%gsa%vrc,this%gsa%vtc,this%gsa%vpc,     &
              &        this%gsa%cvrc,this%gsa%dvrdrc,this%gsa%dvrdtc,   &
              &        this%gsa%dvrdpc,this%gsa%dvtdrc,this%gsa%dvtdpc, &
              &        this%gsa%dvpdrc,this%gsa%dvpdpc,viscLMr,         &
              &        this%nR,1)
         PERFOFF
      end if
  
      !--------- horizontal velocity :
      if ( this%lViscBcCalc ) then

         call get_nlBLayers(this%gsa%vtc,    &
              &             this%gsa%vpc,    &
              &             this%gsa%dvtdrc, &
              &             this%gsa%dvpdrc, &
              &             this%gsa%drSc,   &
              &             this%gsa%dsdtc,  &
              &             this%gsa%dsdpc,  &
              &             uhLMr,duhLMr,gradsLMr,nR,1 )
      end if


      if ( this%lFluxProfCalc ) then
          call get_fluxes(this%gsa%vrc,this%gsa%vtc,             &
                 &        this%gsa%vpc,this%gsa%dvrdrc,          &
                 &        this%gsa%dvtdrc,                       &
                 &        this%gsa%dvpdrc,                       &
                 &        this%gsa%dvrdtc,                       &
                 &        this%gsa%dvrdpc,this%gsa%sc,           &
                 &        this%gsa%pc,this%gsa%brc,              &
                 &        this%gsa%btc,this%gsa%bpc,             &
                 &        this%gsa%cbtc,this%gsa%cbpc,           &
                 &        fconvLMr,fkinLMr,fviscLMr,fpoynLMr,    &
                 &        fresLMr,nR,1 )
      end if

      if ( this%lPerpParCalc ) then
          call get_perpPar(this%gsa%vrc,this%gsa%vtc,       &
                 &         this%gsa%vpc,EperpLMr,EparLMr,   &
                 &         EperpaxiLMr,EparaxiLMr,nR,1 )
      end if


      !--------- Movie output:
      if ( this%l_frame .and. l_movie_oc .and. l_store_frame ) then
         PERFON('mov_out')
         call store_movie_frame(this%nR,this%gsa%vrc,                &
              &                 this%gsa%vtc,this%gsa%vpc,           &
              &                 this%gsa%brc,this%gsa%btc,           &
              &                 this%gsa%bpc,this%gsa%sc,            &
              &                 this%gsa%drSc,                       &
              &                 this%gsa%dvrdpc,                     &
              &                 this%gsa%dvpdrc,                     &
              &                 this%gsa%dvtdrc,                     &
              &                 this%gsa%dvrdtc,                     &
              &                 this%gsa%cvrc,                       &
              &                 this%gsa%cbrc,                       &
              &                 this%gsa%cbtc,1 ,                    &
              &                 this%sizeThetaB,this%leg_helper%bCMB)
         PERFOFF
      end if


      !--------- Stuff for special output:
      !--------- Calculation of magnetic field production and advection terms
      !          for graphic output:
      if ( l_dtB ) then
         PERFON('dtBLM')
         call get_dtBLM(this%nR,this%gsa%vrc,this%gsa%vtc,                    &
              &         this%gsa%vpc,this%gsa%brc,                            &
              &         this%gsa%btc,this%gsa%bpc,                            &
              &         1 ,this%sizeThetaB,this%dtB_arrays%BtVrLM,            &
              &         this%dtB_arrays%BpVrLM,this%dtB_arrays%BrVtLM,        &
              &         this%dtB_arrays%BrVpLM,this%dtB_arrays%BtVpLM,        &
              &         this%dtB_arrays%BpVtLM,this%dtB_arrays%BrVZLM,        &
              &         this%dtB_arrays%BtVZLM,this%dtB_arrays%BtVpCotLM,     &
              &         this%dtB_arrays%BpVtCotLM,this%dtB_arrays%BtVZcotLM,  &
              &         this%dtB_arrays%BtVpSn2LM,this%dtB_arrays%BpVtSn2LM,  &
              &         this%dtB_arrays%BtVZsn2LM)
         PERFOFF
      end if


      !--------- Torsional oscillation terms:
      PERFON('TO_terms')
      if ( ( this%lTONext .or. this%lTONext2 ) .and. l_mag ) then
         call getTOnext(this%leg_helper%zAS,this%gsa%brc,   &
              &         this%gsa%btc,this%gsa%bpc,&
              &         this%lTONext,this%lTONext2,dt,dtLast,this%nR, &
              &         1 ,this%sizeThetaB,this%BsLast,      &
              &         this%BpLast,this%BzLast)
      end if

      if ( this%lTOCalc ) then
         call getTO(this%gsa%vrc,this%gsa%vtc,    &
              &     this%gsa%vpc,this%gsa%cvrc,   &
              &     this%gsa%dvpdrc,this%gsa%brc, &
              &     this%gsa%btc,this%gsa%bpc,    &
              &     this%gsa%cbrc,this%gsa%cbtc,  &
              &     this%BsLast,this%BpLast,this%BzLast,              &
              &     this%TO_arrays%dzRstrLM,this%TO_arrays%dzAstrLM,  &
              &     this%TO_arrays%dzCorLM,this%TO_arrays%dzLFLM,     &
              &     dtLast,this%nR,1,this%sizeThetaB)
      end if
      PERFOFF

      lorentz_torque_ic = lorentz_torques_ic
      this%lorentz_torque_ic = lorentz_torques_ic
      lorentz_torque_ma = this%lorentz_torque_ma

      if (DEBUG_OUTPUT) then
         call this%nl_lm%output()
      end if

      !-- Partial calculation of time derivatives (horizontal parts):
      !   input flm...  is in (l,m) space at radial grid points this%nR !
      !   Only dVxBh needed for boundaries !
      !   get_td finally calculates the d*dt terms needed for the
      !   time step performed in s_LMLoop.f . This should be distributed
      !   over the different models that s_LMLoop.f parallelizes over.
      !write(*,"(A,I4,2ES20.13)") "before_td: ", &
      !     &  this%nR,sum(real(conjg(VxBtLM)*VxBtLM)),sum(real(conjg(VxBpLM)*VxBpLM))
      !PERFON('get_td')
      call this%nl_lm%get_td(this%nR, this%nBc, this%lRmsCalc, this%lPressCalc, &
           &                 dVSrLM, dVPrLM, dVXirLM, dVxVhLM, dVxBhLM,         &
           &                 dwdt, dzdt, dpdt, dsdt, dxidt, dbdt, djdt,         &
           &                 this%leg_helper)

      !PERFOFF
      !write(*,"(A,I4,ES20.13)") "after_td:  ", &
      !     & this%nR,sum(real(conjg(dVxBhLM(:,this%nR_Mag))*dVxBhLM(:,this%nR_Mag)))
      !-- Finish calculation of TO variables:
      if ( this%lTOcalc ) then
         call getTOfinish(this%nR, dtLast, this%leg_helper%zAS,             &
              &           this%leg_helper%dzAS, this%leg_helper%ddzAS,      &
              &           this%TO_arrays%dzRstrLM, this%TO_arrays%dzAstrLM, &
              &           this%TO_arrays%dzCorLM, this%TO_arrays%dzLFLM)
      end if

      !--- Form partial horizontal derivaties of magnetic production and
      !    advection terms:
      if ( l_dtB ) then
         PERFON('dtBLM')
         call get_dH_dtBLM(this%nR,this%dtB_arrays%BtVrLM,this%dtB_arrays%BpVrLM,&
              &            this%dtB_arrays%BrVtLM,this%dtB_arrays%BrVpLM,        &
              &            this%dtB_arrays%BtVpLM,this%dtB_arrays%BpVtLM,        &
              &            this%dtB_arrays%BrVZLM,this%dtB_arrays%BtVZLM,        &
              &            this%dtB_arrays%BtVpCotLM,this%dtB_arrays%BpVtCotLM,  &
              &            this%dtB_arrays%BtVpSn2LM,this%dtB_arrays%BpVtSn2LM)
         PERFOFF
      end if
    end subroutine do_iteration_ThetaParallel
!-------------------------------------------------------------------------------
   subroutine transform_to_grid_space(this, gsa)

      class(rIterThetaParallel_t) :: this
      type(grid_space_arrays_t) :: gsa

      integer :: nR
      nR = this%nR

      if ( l_conv .or. l_mag_kin ) then
         if ( l_heat ) then
            call scal_to_spat(s_Rloc(:, nR), gsa%sc)
            if ( this%lViscBcCalc ) then
               call scal_to_grad_spat(s_Rloc(:, nR), gsa%dsdtc, &
                                      gsa%dsdpc)
               if (this%nR == n_r_cmb .and. ktops==1) then
                  gsa%dsdtc=0.0_cp
                  gsa%dsdpc=0.0_cp
               end if
               if (this%nR == n_r_icb .and. kbots==1) then
                  gsa%dsdtc=0.0_cp
                  gsa%dsdpc=0.0_cp
               end if
            end if
         end if

         if ( this%lPressCalc ) then ! Pressure
            call scal_to_spat(p_Rloc(:, nR), gsa%pc)
         end if

         if ( l_chemical_conv ) then ! Chemical composition
            call scal_to_spat(xi_Rloc(:, nR), gsa%xic)
         end if

         if ( l_HT .or. this%lViscBcCalc ) then
            call scal_to_spat(ds_Rloc(:, nR), gsa%drsc)
         endif
         if ( this%nBc == 0 ) then
            call torpol_to_spat(w_Rloc(:, nR), dw_Rloc(:, nR),  z_Rloc(:, nR), &
                                gsa%vrc, &
                                gsa%vtc, &
                                gsa%vpc)
            if ( this%lDeriv ) then
               call torpol_to_spat(dw_Rloc(:, nR), ddw_Rloc(:, nR), dz_Rloc(:, nR), &
                                   gsa%dvrdrc, &
                                   gsa%dvtdrc, &
                                   gsa%dvpdrc)

               call pol_to_curlr_spat(z_Rloc(:, nR), gsa%cvrc)

               call pol_to_grad_spat(w_Rloc(:, nR), &
                                     gsa%dvrdtc, &
                                     gsa%dvrdpc)
               call torpol_to_dphspat(dw_Rloc(:, nR),  z_Rloc(:, nR), &
                                      gsa%dvtdpc, &
                                      gsa%dvpdpc)

            end if
         else if ( this%nBc == 1 ) then ! Stress free
             ! TODO don't compute vrc as it is set to 0 afterward
            call torpol_to_spat(w_Rloc(:, nR), dw_Rloc(:, nR),  z_Rloc(:, nR), &
                                gsa%vrc, &
                                gsa%vtc, &
                                gsa%vpc)
            gsa%vrc = 0.0_cp
            if ( this%lDeriv ) then
               gsa%dvrdtc = 0.0_cp
               gsa%dvrdpc = 0.0_cp
               call torpol_to_spat(dw_Rloc(:, nR), ddw_Rloc(:, nR), dz_Rloc(:, nR), &
                                   gsa%dvrdrc, &
                                   gsa%dvtdrc, &
                                   gsa%dvpdrc)
               call pol_to_curlr_spat(z_Rloc(:, nR), gsa%cvrc)
               call torpol_to_dphspat(dw_Rloc(:, nR),  z_Rloc(:, nR), &
                                      gsa%dvtdpc, &
                                      gsa%dvpdpc)
            end if
         else if ( this%nBc == 2 ) then
            if ( this%nR == n_r_cmb ) then
               call v_rigid_boundary(this%nR,this%leg_helper%omegaMA,this%lDeriv, &
                    &                gsa%vrc,gsa%vtc,gsa%vpc,gsa%cvrc,gsa%dvrdtc, &
                    &                gsa%dvrdpc,gsa%dvtdpc,gsa%dvpdpc,            &
                    &                1)
            else if ( this%nR == n_r_icb ) then
               call v_rigid_boundary(this%nR,this%leg_helper%omegaIC,this%lDeriv, &
                    &                gsa%vrc,gsa%vtc,gsa%vpc,gsa%cvrc,gsa%dvrdtc, &
                    &                gsa%dvrdpc,gsa%dvtdpc,gsa%dvpdpc,            &
                    &                1)
            end if
            if ( this%lDeriv ) then
               call torpol_to_spat(dw_Rloc(:, nR), ddw_Rloc(:, nR), dz_Rloc(:, nR), &
                                   gsa%dvrdrc, &
                                   gsa%dvtdrc, &
                                   gsa%dvpdrc)
            end if
         end if
      end if
      if ( l_mag .or. l_mag_LF ) then
         call torpol_to_spat(b_Rloc(:, nR), db_Rloc(:, nR),  aj_Rloc(:, nR),    &
                             gsa%brc,                           &
                             gsa%btc,                           &
                             gsa%bpc)

         if ( this%lDeriv ) then
            call torpol_to_curl_spat(b_Rloc(:, nR), ddb_Rloc(:, nR),        &
                                     aj_Rloc(:, nR), dj_Rloc(:, nR), nR,    &
                                     gsa%cbrc,                              &
                                     gsa%cbtc,                              &
                                     gsa%cbpc)
         end if
      end if

   end subroutine transform_to_grid_space
!-------------------------------------------------------------------------------
   subroutine transform_to_lm_space(this, gsa, nl_lm)
!>@details Performs the following transform (for several fields):
!> DFT(u(φ,θ)) -> ũ(m,θ)       
!>
!
!>@author Rafael Lago, MPCDF
!-------------------------------------------------------------------------------

      class(rIterThetaParallel_t) :: this
      type(grid_space_arrays_t) :: gsa
      type(nonlinear_lm_t) :: nl_lm
      
      ! Local variables
      integer :: nTheta, nPhi
      
      integer :: status

      call shtns_load_cfg(1)

      if ( (.not.this%isRadialBoundaryPoint .or. this%lRmsCalc) &
            .and. ( l_conv_nl .or. l_mag_LF ) ) then
         !PERFON('inner1')
         if ( l_conv_nl .and. l_mag_LF ) then
            if ( this%nR>n_r_LCR ) then
               do nTheta=1,this%sizeThetaB
                  do nPhi=1, n_phi_max
                     gsa%Advr(nPhi, nTheta)=gsa%Advr(nPhi, nTheta) + gsa%LFr(nPhi, nTheta)
                     gsa%Advt(nPhi, nTheta)=gsa%Advt(nPhi, nTheta) + gsa%LFt(nPhi, nTheta)
                     gsa%Advp(nPhi, nTheta)=gsa%Advp(nPhi, nTheta) + gsa%LFp(nPhi, nTheta)
                  end do
               end do
            end if
         else if ( l_mag_LF ) then
            if ( this%nR > n_r_LCR ) then
               do nTheta=1, this%sizeThetaB
                  do nPhi=1, n_phi_max
                     gsa%Advr(nPhi, nTheta) = gsa%LFr(nPhi, nTheta)
                     gsa%Advt(nPhi, nTheta) = gsa%LFt(nPhi, nTheta)
                     gsa%Advp(nPhi, nTheta) = gsa%LFp(nPhi, nTheta)
                  end do
               end do
            else
               do nTheta=1, this%sizeThetaB
                  do nPhi=1, n_phi_max
                     gsa%Advr(nPhi,nTheta)=0.0_cp
                     gsa%Advt(nPhi,nTheta)=0.0_cp
                     gsa%Advp(nPhi,nTheta)=0.0_cp
                  end do
               end do
            end if
         end if
        
         ! Computes the transform
         call spat_to_SH_parallel(gsa%Advr, nl_lm%AdvrLM, "Advr")
         call spat_to_SH_parallel(gsa%Advt, nl_lm%AdvtLM, "Advt")
         call spat_to_SH_parallel(gsa%Advp, nl_lm%AdvpLM, "Advp")

         if ( this%lRmsCalc .and. l_mag_LF .and. this%nR>n_r_LCR ) then
            ! LF treated extra:
            call spat_to_SH_parallel(gsa%LFr, nl_lm%LFrLM, "LFr")
            call spat_to_SH_parallel(gsa%LFt, nl_lm%LFtLM, "LFt")
            call spat_to_SH_parallel(gsa%LFp, nl_lm%LFpLM, "LFp")
         end if
         !PERFOFF
      end if
      if ( (.not.this%isRadialBoundaryPoint) .and. l_heat ) then
         !PERFON('inner2')
         call spat_to_SH_parallel(gsa%VSr, nl_lm%VSrLM, "VSr")
         call spat_to_SH_parallel(gsa%VSt, nl_lm%VStLM, "VSt")
         call spat_to_SH_parallel(gsa%VSp, nl_lm%VSpLM, "VSp")

         if (l_anel) then ! anelastic stuff
            if ( l_mag_nl .and. this%nR>n_r_LCR ) then
               call spat_to_SH_parallel(gsa%ViscHeat, nl_lm%ViscHeatLM, "ViscHeat")
               call spat_to_SH_parallel(gsa%OhmLoss, nl_lm%OhmLossLM, "OhmLoss")
            else
               call spat_to_SH_parallel(gsa%ViscHeat, nl_lm%ViscHeatLM, "ViscHeat")
            end if
         end if
         !PERFOFF
      end if
      if ( (.not.this%isRadialBoundaryPoint) .and. l_TP_form ) then
         !PERFON('inner2')
         call spat_to_SH_parallel(gsa%VPr, nl_lm%VPrLM, "VPr")
         !PERFOFF
      end if
      if ( (.not.this%isRadialBoundaryPoint) .and. l_chemical_conv ) then
         !PERFON('inner2')
         call spat_to_SH_parallel(gsa%VXir, nl_lm%VXirLM, "VXir")
         call spat_to_SH_parallel(gsa%VXit, nl_lm%VXitLM, "VXit")
         call spat_to_SH_parallel(gsa%VXip, nl_lm%VXipLM, "VXip")
         !PERFOFF
      end if
      if ( l_mag_nl ) then
         !PERFON('mag_nl')
         if ( .not.this%isRadialBoundaryPoint .and. this%nR>n_r_LCR ) then
            call spat_to_SH_parallel(gsa%VxBr, nl_lm%VxBrLM, "VxBr")
            call spat_to_SH_parallel(gsa%VxBt, nl_lm%VxBtLM, "VxBt")
            call spat_to_SH_parallel(gsa%VxBp, nl_lm%VxBpLM, "VxBp")
         else
            !write(*,"(I4,A,ES20.13)") this%nR,", VxBt = ",sum(VxBt*VxBt)
            call spat_to_SH_parallel(gsa%VxBt, nl_lm%VxBtLM, "VxBt")
            call spat_to_SH_parallel(gsa%VxBp, nl_lm%VxBpLM, "VxBp")
         end if
         !PERFOFF
      end if

      if ( this%lRmsCalc ) then
         call spat_to_SH_parallel(gsa%p1, nl_lm%p1LM, "p1")
         call spat_to_SH_parallel(gsa%p2, nl_lm%p2LM, "p2")
         call spat_to_SH_parallel(gsa%CFt2, nl_lm%CFt2LM, "CFt2")
         call spat_to_SH_parallel(gsa%CFp2, nl_lm%CFp2LM, "CFp2")
         if ( l_conv_nl ) then
            call spat_to_SH_parallel(gsa%Advt2, nl_lm%Advt2LM, "Advt2")
            call spat_to_SH_parallel(gsa%Advp2, nl_lm%Advp2LM, "Advp2")
         end if
         if ( l_mag_nl .and. this%nR>n_r_LCR ) then
            call spat_to_SH_parallel(gsa%LFt2, nl_lm%LFt2LM, "LFt2")
            call spat_to_SH_parallel(gsa%LFp2, nl_lm%LFp2LM, "LFp2")
         end if
      end if
      
      call shtns_load_cfg(0)

   end subroutine transform_to_lm_space
!-------------------------------------------------------------------------------
end module rIterThetaParallel_mod

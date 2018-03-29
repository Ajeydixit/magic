module general_arrays_mod
 
   implicit none
 
   private
 
   type, public, abstract :: general_arrays_t
 
   end type general_arrays_t
 
end module general_arrays_mod
!----------------------------------------------------------------------------
module grid_space_arrays_mod

   use general_arrays_mod
   use precision_mod
   use mem_alloc, only: bytes_allocated
   use truncation, only: nrp, n_phi_max, n_theta_beg, n_theta_end
   use radial_functions, only: or2, orho1, beta, otemp1, visc, r, &
       &                       lambda, or4, or1, alpha0, temp0
   use physical_parameters, only: LFfac, n_r_LCR, CorFac, prec_angle,  &
       &                          ThExpNb, ViscHeatFac, oek, po
   use blocking, only: nfs, sizeThetaB
   use horizontal_data, only: osn2, cosn2, sinTheta, cosTheta, osn1, phi 
   use constants, only: two, third
   use logic, only: l_conv_nl, l_heat_nl, l_mag_nl, l_anel, l_mag_LF, &
       &            l_RMS, l_chemical_conv, l_TP_form, l_precession

   implicit none

   private

   type, public, extends(general_arrays_t) :: grid_space_arrays_t
      !----- Nonlinear terms in phi/theta space: 
      real(cp), allocatable :: Advr(:,:), Advt(:,:), Advp(:,:)
      real(cp), allocatable :: LFr(:,:), LFt(:,:), LFp(:,:)
      real(cp), allocatable :: PCr(:,:), PCt(:,:), PCp(:,:)
      real(cp), allocatable :: VxBr(:,:), VxBt(:,:), VxBp(:,:)
      real(cp), allocatable :: VSr(:,:), VSt(:,:), VSp(:,:)
      real(cp), allocatable :: VXir(:,:), VXit(:,:), VXip(:,:)
      real(cp), allocatable :: VPr(:,:)
      real(cp), allocatable :: ViscHeat(:,:), OhmLoss(:,:)

      !---- RMS calculations
      real(cp), allocatable :: Advt2(:,:), Advp2(:,:)
      real(cp), allocatable :: LFt2(:,:), LFp2(:,:)
      real(cp), allocatable :: CFt2(:,:), CFp2(:,:)
      real(cp), allocatable :: dpdtc(:,:), dpdpc(:,:)

      !----- Fields calculated from these help arrays by legtf:
      real(cp), pointer :: vrc(:,:), vtc(:,:), vpc(:,:)
      real(cp), pointer :: dvrdrc(:,:), dvtdrc(:,:), dvpdrc(:,:)
      real(cp), pointer :: cvrc(:,:), sc(:,:), drSc(:,:)
      real(cp), pointer :: dvrdtc(:,:), dvrdpc(:,:)
      real(cp), pointer :: dvtdpc(:,:), dvpdpc(:,:)
      real(cp), pointer :: brc(:,:), btc(:,:), bpc(:,:)
      real(cp), pointer :: cbrc(:,:), cbtc(:,:), cbpc(:,:)
      real(cp), pointer :: pc(:,:), xic(:,:)
      real(cp), pointer :: dsdtc(:,:), dsdpc(:,:)

   contains

      procedure :: initialize
      procedure :: finalize
      procedure :: output
      procedure :: output_nl_input
      procedure :: get_nl
#ifdef WITH_SHTNS
      procedure :: get_nl_shtns
#endif

   end type grid_space_arrays_t

contains

   subroutine initialize(this)

      class(grid_space_arrays_t) :: this

      allocate( this%Advr(nrp,nfs) )
      allocate( this%Advt(nrp,nfs) )
      allocate( this%Advp(nrp,nfs) )
      allocate( this%LFr(nrp,nfs) )
      allocate( this%LFt(nrp,nfs) )
      allocate( this%LFp(nrp,nfs) )
      allocate( this%VxBr(nrp,nfs) )
      allocate( this%VxBt(nrp,nfs) )
      allocate( this%VxBp(nrp,nfs) )
      allocate( this%VSr(nrp,nfs) )
      allocate( this%VSt(nrp,nfs) )
      allocate( this%VSp(nrp,nfs) )
      allocate( this%ViscHeat(nrp,nfs) )
      allocate( this%OhmLoss(nrp,nfs) )
      bytes_allocated=bytes_allocated + 14*nrp*nfs*SIZEOF_DEF_REAL

      if ( l_TP_form ) then
         allocate( this%VPr(nrp,nfs) )
         bytes_allocated=bytes_allocated + nrp*nfs*SIZEOF_DEF_REAL
      end if

      if ( l_precession ) then
         allocate( this%PCr(nrp,nfs) )
         allocate( this%PCt(nrp,nfs) )
         allocate( this%PCp(nrp,nfs) )
         bytes_allocated=bytes_allocated + 3*nrp*nfs*SIZEOF_DEF_REAL
      end if

      if ( l_chemical_conv ) then
         allocate( this%VXir(nrp,nfs) )
         allocate( this%VXit(nrp,nfs) )
         allocate( this%VXip(nrp,nfs) )
         bytes_allocated=bytes_allocated + 3*nrp*nfs*SIZEOF_DEF_REAL
      end if

      !----- Fields calculated from these help arrays by legtf:
      allocate( this%vrc(nrp,nfs),this%vtc(nrp,nfs),this%vpc(nrp,nfs) )
      allocate( this%dvrdrc(nrp,nfs),this%dvtdrc(nrp,nfs) )
      allocate( this%dvpdrc(nrp,nfs),this%cvrc(nrp,nfs) )
      allocate( this%dvrdtc(nrp,nfs),this%dvrdpc(nrp,nfs) )
      allocate( this%dvtdpc(nrp,nfs),this%dvpdpc(nrp,nfs) )
      allocate( this%brc(nrp,nfs),this%btc(nrp,nfs),this%bpc(nrp,nfs) )
      this%btc=1.0e50_cp
      this%bpc=1.0e50_cp
      allocate( this%cbrc(nrp,nfs),this%cbtc(nrp,nfs),this%cbpc(nrp,nfs) )
      allocate( this%sc(nrp,nfs),this%drSc(nrp,nfs) )
      allocate( this%pc(nrp,nfs) )
      allocate( this%dsdtc(nrp,nfs),this%dsdpc(nrp,nfs) )
      bytes_allocated=bytes_allocated + 22*nrp*nfs*SIZEOF_DEF_REAL

      if ( l_chemical_conv ) then
         allocate( this%xic(nrp,nfs) )
         bytes_allocated=bytes_allocated + nrp*nfs*SIZEOF_DEF_REAL
      else
         allocate( this%xic(1,1) )
      end if

      !-- RMS Calculations
      if ( l_RMS ) then
         allocate ( this%Advt2(nrp,nfs) )
         allocate ( this%Advp2(nrp,nfs) )
         allocate ( this%LFt2(nrp,nfs) )
         allocate ( this%LFp2(nrp,nfs) )
         allocate ( this%CFt2(nrp,nfs) )
         allocate ( this%CFp2(nrp,nfs) )
         allocate ( this%dpdtc(nrp,nfs) )
         allocate ( this%dpdpc(nrp,nfs) )
         bytes_allocated=bytes_allocated + 8*nrp*nfs*SIZEOF_DEF_REAL
      end if
      !write(*,"(A,I15,A)") "grid_space_arrays: allocated ",bytes_allocated,"B."

   end subroutine initialize
!----------------------------------------------------------------------------
   subroutine finalize(this)

      class(grid_space_arrays_t) :: this

      deallocate( this%Advr )
      deallocate( this%Advt )
      deallocate( this%Advp )
      deallocate( this%LFr )
      deallocate( this%LFt )
      deallocate( this%LFp )
      deallocate( this%VxBr )
      deallocate( this%VxBt )
      deallocate( this%VxBp )
      deallocate( this%VSr )
      deallocate( this%VSt )
      deallocate( this%VSp )
      if ( l_TP_form ) deallocate( this%VPr )
      if ( l_chemical_conv ) deallocate( this%VXir, this%VXit, this%VXip )
      if ( l_precession ) deallocate( this%PCr, this%PCt, this%PCp )
      deallocate( this%ViscHeat )
      deallocate( this%OhmLoss )

      !----- Fields calculated from these help arrays by legtf:
      deallocate( this%vrc,this%vtc,this%vpc )
      deallocate( this%dvrdrc,this%dvtdrc )
      deallocate( this%dvpdrc,this%cvrc )
      deallocate( this%dvrdtc,this%dvrdpc )
      deallocate( this%dvtdpc,this%dvpdpc )
      deallocate( this%brc,this%btc,this%bpc )
      deallocate( this%cbrc,this%cbtc,this%cbpc )
      deallocate( this%sc,this%drSc )
      deallocate( this%pc, this%xic )
      deallocate( this%dsdtc, this%dsdpc )

      !-- RMS Calculations
      if ( l_RMS ) then
         deallocate ( this%Advt2 )
         deallocate ( this%Advp2 )
         deallocate ( this%LFt2 )
         deallocate ( this%LFp2 )
         deallocate ( this%CFt2 )
         deallocate ( this%CFp2 )
         deallocate ( this%dpdtc )
         deallocate ( this%dpdpc )
      end if

   end subroutine finalize
!----------------------------------------------------------------------------
   subroutine output(this)

      class(grid_space_arrays_t) :: this
   
      write(*,"(A,3ES20.12)") "Advr,Advt,Advp = ",sum(this%Advr), &
                                   sum(this%Advt),sum(this%Advp)

   end subroutine output
!----------------------------------------------------------------------------
   subroutine output_nl_input(this)

      class(grid_space_arrays_t) :: this
   
      write(*,"(A,6ES20.12)") "vr,vt,vp = ",sum(this%vrc),sum(this%vtc), &
                                            sum(this%vpc)

   end subroutine output_nl_input
!----------------------------------------------------------------------------
#ifdef WITH_SHTNS
   subroutine get_nl_shtns(this, time, nR, nBc, lRmsCalc)
      !
      !  calculates non-linear products in grid-space for radial
      !  level nR and returns them in arrays wnlr1-3, snlr1-3, bnlr1-3
      !
      !  if nBc >0 velocities are zero only the (vxB)
      !  contributions to bnlr2-3 need to be calculated
      !
      !  vr...sr: (input) velocity, magnetic field comp. and derivs, entropy
      !                   on grid points
      !  nR: (input) radial level
      !  i1: (input) range of points in theta for which calculation is done
      !

      class(grid_space_arrays_t) :: this

      !-- Input of variables:
      real(cp), intent(in) :: time
      integer,  intent(in) :: nR
      logical,  intent(in) :: lRmsCalc
      integer,  intent(in) :: nBc

      !-- Local variables:
      integer :: nTheta, nThetaNHS
      integer :: nPhi
      real(cp) :: or2sn2, or4sn2, csn2, cnt, rsnt, snt, posnalp


      if ( l_mag_LF .and. (nBc == 0 .or. lRmsCalc) .and. nR>n_r_LCR ) then
         !------ Get the Lorentz force:
         do nTheta=n_theta_beg, n_theta_end

            nThetaNHS=(nTheta+1)/2
            or4sn2   =or4(nR)*osn2(nThetaNHS)

            do nPhi=1,n_phi_max
               !---- LFr= r**2/(E*Pm) * ( curl(B)_t*B_p - curl(B)_p*B_t )
               this%LFr(nPhi,nTheta)=  LFfac*osn2(nThetaNHS) * (        &
               &        this%cbtc(nPhi,nTheta)*this%bpc(nPhi,nTheta) - &
               &        this%cbpc(nPhi,nTheta)*this%btc(nPhi,nTheta) )
            end do

            !---- LFt= 1/(E*Pm) * 1/(r*sin(theta)) * ( curl(B)_p*B_r - curl(B)_r*B_p )
            do nPhi=1,n_phi_max
               this%LFt(nPhi,nTheta)=           LFfac*or4sn2 * (        &
               &        this%cbpc(nPhi,nTheta)*this%brc(nPhi,nTheta) - &
               &        this%cbrc(nPhi,nTheta)*this%bpc(nPhi,nTheta) )
            end do
            !---- LFp= 1/(E*Pm) * 1/(r*sin(theta)) * ( curl(B)_r*B_t - curl(B)_t*B_r )
            do nPhi=1,n_phi_max
               this%LFp(nPhi,nTheta)=           LFfac*or4sn2 * (        &
               &        this%cbrc(nPhi,nTheta)*this%btc(nPhi,nTheta) - &
               &        this%cbtc(nPhi,nTheta)*this%brc(nPhi,nTheta) )
            end do

         end do   ! theta loop
      end if      ! Lorentz force required ?

      if ( l_conv_nl .and. (nBc == 0 .or. lRmsCalc) ) then

         !------ Get Advection:
         do nTheta=n_theta_beg, n_theta_end ! loop over theta points in block
            nThetaNHS=(nTheta+1)/2
            or4sn2   =or4(nR)*osn2(nThetaNHS)
            csn2     =cosn2(nThetaNHS)
            if ( mod(nTheta,2) == 0 ) csn2=-csn2 ! South, odd function in theta

            do nPhi=1,n_phi_max
               this%Advr(nPhi,nTheta)=          -or2(nR)*orho1(nR) * (  &
               &                                this%vrc(nPhi,nTheta) * &
               &                     (       this%dvrdrc(nPhi,nTheta) - &
               &    ( two*or1(nR)+beta(nR) )*this%vrc(nPhi,nTheta) ) +  &
               &                               osn2(nThetaNHS) * (       &
               &                                this%vtc(nPhi,nTheta) * &
               &                     (       this%dvrdtc(nPhi,nTheta) - &
               &                  r(nR)*      this%vtc(nPhi,nTheta) ) + &
               &                                this%vpc(nPhi,nTheta) * &
               &                     (       this%dvrdpc(nPhi,nTheta) - &
               &                    r(nR)*      this%vpc(nPhi,nTheta) ) ) )
            end do
            do nPhi=1,n_phi_max
               this%Advt(nPhi,nTheta)=         or4sn2*orho1(nR) * (  &
               &                            -this%vrc(nPhi,nTheta) * &
               &                      (   this%dvtdrc(nPhi,nTheta) - &
               &                beta(nR)*this%vtc(nPhi,nTheta) )   + &
               &                             this%vtc(nPhi,nTheta) * &
               &                      ( csn2*this%vtc(nPhi,nTheta) + &
               &                          this%dvpdpc(nPhi,nTheta) + &
               &                      this%dvrdrc(nPhi,nTheta) )   + &
               &                             this%vpc(nPhi,nTheta) * &
               &                      ( csn2*this%vpc(nPhi,nTheta) - &
               &                          this%dvtdpc(nPhi,nTheta) )  )
            end do
            do nPhi=1,n_phi_max
               this%Advp(nPhi,nTheta)=         or4sn2*orho1(nR) * (  &
               &                            -this%vrc(nPhi,nTheta) * &
               &                        ( this%dvpdrc(nPhi,nTheta) - &
               &                beta(nR)*this%vpc(nPhi,nTheta) )   - &
               &                             this%vtc(nPhi,nTheta) * &
               &                        ( this%dvtdpc(nPhi,nTheta) + &
               &                        this%cvrc(nPhi,nTheta) )   - &
               &       this%vpc(nPhi,nTheta) * this%dvpdpc(nPhi,nTheta) )
            end do
         end do ! theta loop

      end if  ! Navier-Stokes nonlinear advection term ?

      if ( l_heat_nl .and. nBc == 0 ) then
         if ( l_TP_form ) then
            !------ Get V S, the divergence of it is entropy advection:
            do nTheta=n_theta_beg, n_theta_end
               nThetaNHS=(nTheta+1)/2
               or2sn2=or2(nR)*osn2(nThetaNHS)
               do nPhi=1,n_phi_max     ! calculate v*s components
                  this%VSr(nPhi,nTheta)=                                   &
                  &    this%vrc(nPhi,nTheta)*this%sc(nPhi,nTheta)
                  this%VSt(nPhi,nTheta)=                                   &
                  &    or2sn2*(this%vtc(nPhi,nTheta)*this%sc(nPhi,nTheta) &
                  &    - alpha0(nR)*temp0(nR)*orho1(nR)*ViscHeatFac*        &
                  &    ThExpNb*this%vtc(nPhi,nTheta)*this%pc(nPhi,nTheta))
                  this%VSp(nPhi,nTheta)=                                   &
                  &    or2sn2*(this%vpc(nPhi,nTheta)*this%sc(nPhi,nTheta) &
                  &    - alpha0(nR)*temp0(nR)*orho1(nR)*ViscHeatFac*        &
                  &    ThExpNb*this%vpc(nPhi,nTheta)*this%pc(nPhi,nTheta))
                  this%VPr(nPhi,nTheta)=                                   &
                  &    this%vrc(nPhi,nTheta)*this%pc(nPhi,nTheta)
               end do
            end do  ! theta loop
         else
            !------ Get V S, the divergence of it is entropy advection:
            do nTheta=n_theta_beg, n_theta_end
               nThetaNHS=(nTheta+1)/2
               or2sn2=or2(nR)*osn2(nThetaNHS)
               do nPhi=1,n_phi_max     ! calculate v*s components
                  this%VSr(nPhi,nTheta)= &
                  &    this%vrc(nPhi,nTheta)*this%sc(nPhi,nTheta)
                  this%VSt(nPhi,nTheta)= &
                  &    or2sn2*this%vtc(nPhi,nTheta)*this%sc(nPhi,nTheta)
                  this%VSp(nPhi,nTheta)= &
                  &    or2sn2*this%vpc(nPhi,nTheta)*this%sc(nPhi,nTheta)
               end do
            end do  ! theta loop
         end if
      end if     ! heat equation required ?

      if ( l_chemical_conv .and. nBc == 0 ) then
         !------ Get V S, the divergence of it is the advection of chem comp:
         do nTheta=n_theta_beg, n_theta_end
            nThetaNHS=(nTheta+1)/2
            or2sn2=or2(nR)*osn2(nThetaNHS)
            do nPhi=1,n_phi_max     ! calculate v*s components
               this%VXir(nPhi,nTheta)= &
               &    this%vrc(nPhi,nTheta)*this%xic(nPhi,nTheta)
               this%VXit(nPhi,nTheta)= &
               &    or2sn2*this%vtc(nPhi,nTheta)*this%xic(nPhi,nTheta)
               this%VXip(nPhi,nTheta)= &
               &    or2sn2*this%vpc(nPhi,nTheta)*this%xic(nPhi,nTheta)
            end do
         end do  ! theta loop
      end if     ! chemical composition equation required ?

      if ( l_precession .and. nBc == 0 ) then
         do nTheta=n_theta_beg, n_theta_end
            nThetaNHS=(nTheta+1)/2
            posnalp=-two*oek*po*sin(prec_angle)*osn1(nThetaNHS)
            cnt=cosTheta(nTheta)
            do nPhi=1,n_phi_max
               this%PCr(nPhi,nTheta)=posnalp*r(nR)*(cos(oek*time+phi(nPhi))* &
               &                                  this%vpc(nPhi,nTheta)*cnt  &
               &            +sin(oek*time+phi(nPhi))*this%vtc(nPhi,nTheta))
               this%PCt(nPhi,nTheta)=   -posnalp*or2(nR)*(                   &
               &               cos(oek*time+phi(nPhi))*this%vpc(nPhi,nTheta) &
               &      +sin(oek*time+phi(nPhi))*or1(nR)*this%vrc(nPhi,nTheta) )
               this%PCp(nPhi,nTheta)= posnalp*cos(oek*time+phi(nPhi))*       &
               &              or2(nR)*(      this%vtc(nPhi,nTheta)-          &
               &                     or1(nR)*this%vrc(nPhi,nTheta)*cnt)
            end do
         end do ! theta loop
         !$OMP END PARALLEL DO

      end if ! precession term required ?

      if ( l_mag_nl ) then

         if ( nBc == 0 .and. nR>n_r_LCR ) then

            !------ Get (V x B) , the curl of this is the dynamo term:
            do nTheta=n_theta_beg, n_theta_end
               nThetaNHS=(nTheta+1)/2
               or4sn2=or4(nR)*osn2(nThetaNHS)

               do nPhi=1,n_phi_max
                  this%VxBr(nPhi,nTheta)=  orho1(nR)*osn2(nThetaNHS) * (        &
                  &              this%vtc(nPhi,nTheta)*this%bpc(nPhi,nTheta) - &
                  &              this%vpc(nPhi,nTheta)*this%btc(nPhi,nTheta) )
               end do
               do nPhi=1,n_phi_max
                  this%VxBt(nPhi,nTheta)=  orho1(nR)*or4sn2 * (        &
                  &     this%vpc(nPhi,nTheta)*this%brc(nPhi,nTheta) - &
                  &     this%vrc(nPhi,nTheta)*this%bpc(nPhi,nTheta) )
               end do
               do nPhi=1,n_phi_max
                  this%VxBp(nPhi,nTheta)=   orho1(nR)*or4sn2 * (        &
                  &      this%vrc(nPhi,nTheta)*this%btc(nPhi,nTheta) - &
                  &      this%vtc(nPhi,nTheta)*this%brc(nPhi,nTheta) )
               end do
            end do   ! theta loop

         else if ( nBc == 1 .or. nR<=n_r_LCR ) then ! stress free boundary
            do nTheta=n_theta_beg, n_theta_end
               nThetaNHS=(nTheta+1)/2
               or4sn2   =or4(nR)*osn2(nThetaNHS)
               do nPhi=1,n_phi_max
                  this%VxBt(nPhi,nTheta)=  or4sn2 * orho1(nR) * &
                  &    this%vpc(nPhi,nTheta)*this%brc(nPhi,nTheta)
                  this%VxBp(nPhi,nTheta)= -or4sn2 * orho1(nR) * &
                  &    this%vtc(nPhi,nTheta)*this%brc(nPhi,nTheta)
               end do
            end do

         else if ( nBc == 2 ) then  ! rigid boundary :

            !----- Only vp /= 0 at boundary allowed (rotation of boundaries about z-axis):
            do nTheta=n_theta_beg, n_theta_end
               nThetaNHS=(nTheta+1)/2
               or4sn2   =or4(nR)*osn2(nThetaNHS)
               do nPhi=1,n_phi_max
                  this%VxBt(nPhi,nTheta)= or4sn2 * orho1(nR) * &
                  &    this%vpc(nPhi,nTheta)*this%brc(nPhi,nTheta)
                  this%VxBp(nPhi,nTheta)= 0.0_cp
               end do
            end do

         end if  ! boundary ?

      end if ! l_mag_nl ?

      if ( l_anel .and. nBc == 0 ) then
         !------ Get viscous heating
         do nTheta=n_theta_beg, n_theta_end ! loop over theta points in block
            nThetaNHS=(nTheta+1)/2
            csn2     =cosn2(nThetaNHS)
            if ( mod(nTheta,2) == 0 ) csn2=-csn2 ! South, odd function in theta

            do nPhi=1,n_phi_max
               this%ViscHeat(nPhi,nTheta)=      or4(nR)*                  &
               &                     orho1(nR)*otemp1(nR)*visc(nR)*(       &
               &     two*(                     this%dvrdrc(nPhi,nTheta) - & ! (1)
               &     (two*or1(nR)+beta(nR))*this%vrc(nphi,nTheta) )**2  + &
               &     two*( csn2*                  this%vtc(nPhi,nTheta) + &
               &                               this%dvpdpc(nphi,nTheta) + &
               &                               this%dvrdrc(nPhi,nTheta) - & ! (2)
               &     or1(nR)*               this%vrc(nPhi,nTheta) )**2  + &
               &     two*(                     this%dvpdpc(nphi,nTheta) + &
               &           csn2*                  this%vtc(nPhi,nTheta) + & ! (3)
               &     or1(nR)*               this%vrc(nPhi,nTheta) )**2  + &
               &          ( two*               this%dvtdpc(nPhi,nTheta) + &
               &                                 this%cvrc(nPhi,nTheta) - & ! (6)
               &      two*csn2*             this%vpc(nPhi,nTheta) )**2  + &
               &                                 osn2(nThetaNHS) * (       &
               &         ( r(nR)*              this%dvtdrc(nPhi,nTheta) - &
               &           (two+beta(nR)*r(nR))*  this%vtc(nPhi,nTheta) + & ! (4)
               &     or1(nR)*            this%dvrdtc(nPhi,nTheta) )**2  + &
               &         ( r(nR)*              this%dvpdrc(nPhi,nTheta) - &
               &           (two+beta(nR)*r(nR))*  this%vpc(nPhi,nTheta) + & ! (5)
               &     or1(nR)*            this%dvrdpc(nPhi,nTheta) )**2 )- &
               &    two*third*(  beta(nR)*        this%vrc(nPhi,nTheta) )**2 )
            end do
         end do ! theta loop

         if ( l_mag_nl .and. nR>n_r_LCR ) then
            !------ Get ohmic losses
            do nTheta=n_theta_beg, n_theta_end ! loop over theta points in block
               nThetaNHS=(nTheta+1)/2
               do nPhi=1,n_phi_max
                  this%OhmLoss(nPhi,nTheta)= or2(nR)*otemp1(nR)*lambda(nR)*  &
                  &    ( or2(nR)*                this%cbrc(nPhi,nTheta)**2 + &
                  &      osn2(nThetaNHS)*        this%cbtc(nPhi,nTheta)**2 + &
                  &      osn2(nThetaNHS)*        this%cbpc(nPhi,nTheta)**2  )
               end do
            end do ! theta loop

         end if ! if l_mag_nl ?

      end if  ! Viscous heating and Ohmic losses ?

      if ( lRmsCalc ) then
         do nTheta=n_theta_beg, n_theta_end ! loop over theta points in block
            snt=sinTheta(nTheta)
            cnt=cosTheta(nTheta)
            rsnt=r(nR)*snt
            do nPhi=1,n_phi_max
               this%dpdtc(nPhi,nTheta)=this%dpdtc(nPhi,nTheta)/r(nR)
               this%dpdpc(nPhi,nTheta)=this%dpdpc(nPhi,nTheta)/r(nR)
               this%CFt2(nPhi,nTheta)=-two*CorFac*cnt*this%vpc(nPhi,nTheta)/r(nR)
               this%CFp2(nPhi,nTheta)= two*CorFac*snt* (                &
               &                     cnt*this%vtc(nPhi,nTheta)/rsnt +   &
               &                     or2(nR)*snt*this%vrc(nPhi,nTheta) )
               if ( l_conv_nl ) then
                  this%Advt2(nPhi,nTheta)=rsnt*snt*this%Advt(nPhi,nTheta)
                  this%Advp2(nPhi,nTheta)=rsnt*snt*this%Advp(nPhi,nTheta)
               end if
               if ( l_mag_LF .and. nR > n_r_LCR ) then
                  this%LFt2(nPhi,nTheta)=rsnt*snt*this%LFt(nPhi,nTheta)
                  this%LFp2(nPhi,nTheta)=rsnt*snt*this%LFp(nPhi,nTheta)
               end if
            end do
         end do
      end if

   end subroutine get_nl_shtns
#endif
!----------------------------------------------------------------------------
   subroutine get_nl(this,time,nR,nBc,nThetaStart,lRmsCalc)
      !
      !  calculates non-linear products in grid-space for radial
      !  level nR and returns them in arrays wnlr1-3, snlr1-3, bnlr1-3
      !
      !  if nBc >0 velocities are zero only the (vxB)
      !  contributions to bnlr2-3 need to be calculated
      !
      !  vr...sr: (input) velocity, magnetic field comp. and derivs, entropy
      !                   on grid points
      !  nR: (input) radial level
      !  i1: (input) range of points in theta for which calculation is done
      !

      class(grid_space_arrays_t) :: this

      !-- Input of variables:
      real(cp), intent(in) :: time
      integer,  intent(in) :: nR
      integer,  intent(in) :: nBc
      integer,  intent(in) :: nThetaStart
      logical,  intent(in) :: lRmsCalc

      !-- Local variables:
      integer :: nTheta
      integer :: nThetaLast,nThetaB,nThetaNHS
      integer :: nPhi
      real(cp) :: or2sn2,or4sn2,csn2,snt,cnt,rsnt,posnalp

      nThetaLast=nThetaStart-1

      if ( l_mag_LF .and. (nBc == 0 .or. lRmsCalc) .and. nR>n_r_LCR ) then
         !------ Get the Lorentz force:
         nTheta=nThetaLast
         do nThetaB=1,sizeThetaB

            nTheta   =nTheta+1
            nThetaNHS=(nTheta+1)/2
            or4sn2   =or4(nR)*osn2(nThetaNHS)

            do nPhi=1,n_phi_max
               !---- LFr= r**2/(E*Pm) * ( curl(B)_t*B_p - curl(B)_p*B_t )
               this%LFr(nPhi,nThetaB)=  LFfac*osn2(nThetaNHS) * (        &
               &        this%cbtc(nPhi,nThetaB)*this%bpc(nPhi,nThetaB) - &
               &        this%cbpc(nPhi,nThetaB)*this%btc(nPhi,nThetaB) )
            end do
            this%LFr(n_phi_max+1,nThetaB)=0.0_cp
            this%LFr(n_phi_max+2,nThetaB)=0.0_cp

            !---- LFt= 1/(E*Pm) * 1/(r*sin(theta)) * ( curl(B)_p*B_r - curl(B)_r*B_p )
            do nPhi=1,n_phi_max
               this%LFt(nPhi,nThetaB)=           LFfac*or4sn2 * (        &
               &        this%cbpc(nPhi,nThetaB)*this%brc(nPhi,nThetaB) - &
               &        this%cbrc(nPhi,nThetaB)*this%bpc(nPhi,nThetaB) )
            end do
            this%LFt(n_phi_max+1,nThetaB)=0.0_cp
            this%LFt(n_phi_max+2,nThetaB)=0.0_cp
            !---- LFp= 1/(E*Pm) * 1/(r*sin(theta)) * ( curl(B)_r*B_t - curl(B)_t*B_r )
            do nPhi=1,n_phi_max
               this%LFp(nPhi,nThetaB)=           LFfac*or4sn2 * (        &
               &        this%cbrc(nPhi,nThetaB)*this%btc(nPhi,nThetaB) - &
               &        this%cbtc(nPhi,nThetaB)*this%brc(nPhi,nThetaB) )
            end do
            this%LFp(n_phi_max+1,nThetaB)=0.0_cp
            this%LFp(n_phi_max+2,nThetaB)=0.0_cp

         end do   ! theta loop
      end if      ! Lorentz force required ?

      if ( l_conv_nl .and. (nBc == 0 .or. lRmsCalc) ) then

         !------ Get Advection:
         nTheta=nThetaLast
         do nThetaB=1,sizeThetaB ! loop over theta points in block
            nTheta   =nTheta+1
            nThetaNHS=(nTheta+1)/2
            or4sn2   =or4(nR)*osn2(nThetaNHS)
            csn2     =cosn2(nThetaNHS)
            if ( mod(nTheta,2) == 0 ) csn2=-csn2 ! South, odd function in theta

            do nPhi=1,n_phi_max
               this%Advr(nPhi,nThetaB)=          -or2(nR)*orho1(nR) * (  &
               &                                this%vrc(nPhi,nThetaB) * &
               &                     (       this%dvrdrc(nPhi,nThetaB) - &
               &    ( two*or1(nR)+beta(nR) )*this%vrc(nPhi,nThetaB) ) +  &
               &                               osn2(nThetaNHS) * (       &
               &                                this%vtc(nPhi,nThetaB) * &
               &                     (       this%dvrdtc(nPhi,nThetaB) - &
               &                  r(nR)*      this%vtc(nPhi,nThetaB) ) + &
               &                                this%vpc(nPhi,nThetaB) * &
               &                     (       this%dvrdpc(nPhi,nThetaB) - &
               &                    r(nR)*      this%vpc(nPhi,nThetaB) ) ) )
            end do
            this%Advr(n_phi_max+1,nThetaB)=0.0_cp
            this%Advr(n_phi_max+2,nThetaB)=0.0_cp
            do nPhi=1,n_phi_max
               this%Advt(nPhi,nThetaB)=         or4sn2*orho1(nR) * (  &
               &                            -this%vrc(nPhi,nThetaB) * &
               &                      (   this%dvtdrc(nPhi,nThetaB) - &
               &                beta(nR)*this%vtc(nPhi,nThetaB) )   + &
               &                             this%vtc(nPhi,nThetaB) * &
               &                      ( csn2*this%vtc(nPhi,nThetaB) + &
               &                          this%dvpdpc(nPhi,nThetaB) + &
               &                      this%dvrdrc(nPhi,nThetaB) )   + &
               &                             this%vpc(nPhi,nThetaB) * &
               &                      ( csn2*this%vpc(nPhi,nThetaB) - &
               &                          this%dvtdpc(nPhi,nThetaB) )  )
            end do
            this%Advt(n_phi_max+1,nThetaB)=0.0_cp
            this%Advt(n_phi_max+2,nThetaB)=0.0_cp
            do nPhi=1,n_phi_max
               this%Advp(nPhi,nThetaB)=         or4sn2*orho1(nR) * (  &
               &                            -this%vrc(nPhi,nThetaB) * &
               &                        ( this%dvpdrc(nPhi,nThetaB) - &
               &                beta(nR)*this%vpc(nPhi,nThetaB) )   - &
               &                             this%vtc(nPhi,nThetaB) * &
               &                        ( this%dvtdpc(nPhi,nThetaB) + &
               &                        this%cvrc(nPhi,nThetaB) )   - &
               &       this%vpc(nPhi,nThetaB) * this%dvpdpc(nPhi,nThetaB) )
            end do
            this%Advp(n_phi_max+1,nThetaB)=0.0_cp
            this%Advp(n_phi_max+2,nThetaB)=0.0_cp
         end do ! theta loop

      end if  ! Navier-Stokes nonlinear advection term ?

      if ( l_heat_nl .and. nBc == 0 ) then
         !------ Get V S, the divergence of the is entropy advection:
         if ( l_TP_form ) then
            nTheta=nThetaLast
            do nThetaB=1,sizeThetaB
               nTheta   =nTheta+1
               nThetaNHS=(nTheta+1)/2
               or2sn2=or2(nR)*osn2(nThetaNHS)
               do nPhi=1,n_phi_max     ! calculate v*s components
                  this%VSr(nPhi,nThetaB)=                                   &
                  &    this%vrc(nPhi,nThetaB)*this%sc(nPhi,nThetaB)
                  this%VSt(nPhi,nThetaB)=                                   &
                  &    or2sn2*(this%vtc(nPhi,nThetaB)*this%sc(nPhi,nThetaB) &
                  &    - alpha0(nR)*temp0(nR)*orho1(nR)*ViscHeatFac*        &
                  &    ThExpNb*this%vtc(nPhi,nThetaB)*this%pc(nPhi,nThetaB))
                  this%VSp(nPhi,nThetaB)=                                   &
                  &    or2sn2*(this%vpc(nPhi,nThetaB)*this%sc(nPhi,nThetaB) &
                  &    - alpha0(nR)*temp0(nR)*orho1(nR)*ViscHeatFac*        &
                  &    ThExpNb*this%vpc(nPhi,nThetaB)*this%pc(nPhi,nThetaB))
                  this%VPr(nPhi,nThetaB)=                                   &
                  &    this%vrc(nPhi,nThetaB)*this%pc(nPhi,nThetaB)
               end do
               this%VSr(n_phi_max+1,nThetaB)=0.0_cp
               this%VSr(n_phi_max+2,nThetaB)=0.0_cp
               this%VSt(n_phi_max+1,nThetaB)=0.0_cp
               this%VSt(n_phi_max+2,nThetaB)=0.0_cp
               this%VSp(n_phi_max+1,nThetaB)=0.0_cp
               this%VSp(n_phi_max+2,nThetaB)=0.0_cp
               this%VPr(n_phi_max+1,nThetaB)=0.0_cp
               this%VPr(n_phi_max+2,nThetaB)=0.0_cp
            end do  ! theta loop
         else
            nTheta=nThetaLast
            do nThetaB=1,sizeThetaB
               nTheta   =nTheta+1
               nThetaNHS=(nTheta+1)/2
               or2sn2=or2(nR)*osn2(nThetaNHS)
               do nPhi=1,n_phi_max     ! calculate v*s components
                  this%VSr(nPhi,nThetaB)= &
                  &    this%vrc(nPhi,nThetaB)*this%sc(nPhi,nThetaB)
                  this%VSt(nPhi,nThetaB)= &
                  &    or2sn2*this%vtc(nPhi,nThetaB)*this%sc(nPhi,nThetaB)
                  this%VSp(nPhi,nThetaB)= &
                  &    or2sn2*this%vpc(nPhi,nThetaB)*this%sc(nPhi,nThetaB)
               end do
               this%VSr(n_phi_max+1,nThetaB)=0.0_cp
               this%VSr(n_phi_max+2,nThetaB)=0.0_cp
               this%VSt(n_phi_max+1,nThetaB)=0.0_cp
               this%VSt(n_phi_max+2,nThetaB)=0.0_cp
               this%VSp(n_phi_max+1,nThetaB)=0.0_cp
               this%VSp(n_phi_max+2,nThetaB)=0.0_cp
            end do  ! theta loop
         end if
      end if     ! heat equation required ?

      if ( l_chemical_conv .and. nBc == 0 ) then
         !------ Get V Xi, the divergence of the is advection of chemical comp:
         nTheta=nThetaLast
         do nThetaB=1,sizeThetaB
            nTheta   =nTheta+1
            nThetaNHS=(nTheta+1)/2
            or2sn2=or2(nR)*osn2(nThetaNHS)
            do nPhi=1,n_phi_max     ! calculate v*s components
               this%VXir(nPhi,nThetaB)= &
               &    this%vrc(nPhi,nThetaB)*this%xic(nPhi,nThetaB)
               this%VXit(nPhi,nThetaB)= &
               &    or2sn2*this%vtc(nPhi,nThetaB)*this%xic(nPhi,nThetaB)
               this%VXip(nPhi,nThetaB)= &
               &    or2sn2*this%vpc(nPhi,nThetaB)*this%xic(nPhi,nThetaB)
            end do
            this%VXir(n_phi_max+1,nThetaB)=0.0_cp
            this%VXir(n_phi_max+2,nThetaB)=0.0_cp
            this%VXit(n_phi_max+1,nThetaB)=0.0_cp
            this%VXit(n_phi_max+2,nThetaB)=0.0_cp
            this%VXip(n_phi_max+1,nThetaB)=0.0_cp
            this%VXip(n_phi_max+2,nThetaB)=0.0_cp
         end do  ! theta loop
      end if     ! chemical composition equation required ?

      if ( l_precession .and. nBc == 0 ) then
         nTheta=nThetaLast
         do nThetaB=1,sizeThetaB
            nTheta=nTheta+1
            nThetaNHS=(nTheta+1)/2
            posnalp=-two*oek*po*sin(prec_angle)*osn1(nThetaNHS)
            cnt=cosTheta(nTheta)
            do nPhi=1,n_phi_max
               this%PCr(nPhi,nThetaB)=posnalp*r(nR)*(cos(oek*time+phi(nPhi))* &
               &                                  this%vpc(nPhi,nThetaB)*cnt  &
               &            +sin(oek*time+phi(nPhi))*this%vtc(nPhi,nThetaB))
               this%PCt(nPhi,nThetaB)= -posnalp*or2(nR)*(                     &
               &               cos(oek*time+phi(nPhi))*this%vpc(nPhi,nThetaB) &
               &      +sin(oek*time+phi(nPhi))*or1(nR)*this%vrc(nPhi,nThetaB) )
               this%PCp(nPhi,nThetaB)= posnalp*cos(oek*time+phi(nPhi))*       &
               &              or2(nR)*(      this%vtc(nPhi,nThetaB)-          &
               &                     or1(nR)*this%vrc(nPhi,nThetaB)*cnt)
            end do
            this%PCr(n_phi_max+1,nThetaB)=0.0_cp
            this%PCr(n_phi_max+2,nThetaB)=0.0_cp
            this%PCt(n_phi_max+1,nThetaB)=0.0_cp
            this%PCt(n_phi_max+2,nThetaB)=0.0_cp
            this%PCp(n_phi_max+1,nThetaB)=0.0_cp
            this%PCp(n_phi_max+2,nThetaB)=0.0_cp
         end do ! theta loop
      end if ! precession term required ?

      if ( l_mag_nl ) then

         if ( nBc == 0 .and. nR>n_r_LCR ) then

            !------ Get (V x B) , the curl of this is the dynamo term:
            nTheta=nThetaLast
            do nThetaB=1,sizeThetaB
               nTheta   =nTheta+1
               nThetaNHS=(nTheta+1)/2
               or4sn2=or4(nR)*osn2(nThetaNHS)

               do nPhi=1,n_phi_max
                  this%VxBr(nPhi,nThetaB)=  orho1(nR)*osn2(nThetaNHS) * (        &
                  &              this%vtc(nPhi,nThetaB)*this%bpc(nPhi,nThetaB) - &
                  &              this%vpc(nPhi,nThetaB)*this%btc(nPhi,nThetaB) )
               end do
               this%VxBr(n_phi_max+1,nThetaB)=0.0_cp
               this%VxBr(n_phi_max+2,nThetaB)=0.0_cp

               do nPhi=1,n_phi_max
                  this%VxBt(nPhi,nThetaB)=  orho1(nR)*or4sn2 * (        &
                  &     this%vpc(nPhi,nThetaB)*this%brc(nPhi,nThetaB) - &
                  &     this%vrc(nPhi,nThetaB)*this%bpc(nPhi,nThetaB) )
               end do
               this%VxBt(n_phi_max+1,nThetaB)=0.0_cp
               this%VxBt(n_phi_max+2,nThetaB)=0.0_cp

               do nPhi=1,n_phi_max
                  this%VxBp(nPhi,nThetaB)=   orho1(nR)*or4sn2 * (        &
                  &      this%vrc(nPhi,nThetaB)*this%btc(nPhi,nThetaB) - &
                  &      this%vtc(nPhi,nThetaB)*this%brc(nPhi,nThetaB) )
               end do
               this%VxBp(n_phi_max+1,nThetaB)=0.0_cp
               this%VxBp(n_phi_max+2,nThetaB)=0.0_cp
            end do   ! theta loop

         else if ( nBc == 1 .or. nR<=n_r_LCR ) then ! stress free boundary

            nTheta=nThetaLast
            do nThetaB=1,sizeThetaB
               nTheta   =nTheta+1
               nThetaNHS=(nTheta+1)/2
               or4sn2   =or4(nR)*osn2(nThetaNHS)
               do nPhi=1,n_phi_max
                  this%VxBt(nPhi,nThetaB)=  or4sn2 * orho1(nR) * &
                  &    this%vpc(nPhi,nThetaB)*this%brc(nPhi,nThetaB)
                  this%VxBp(nPhi,nThetaB)= -or4sn2 * orho1(nR) * &
                  &    this%vtc(nPhi,nThetaB)*this%brc(nPhi,nThetaB)
               end do
               this%VxBt(n_phi_max+1,nThetaB)=0.0_cp
               this%VxBt(n_phi_max+2,nThetaB)=0.0_cp
               this%VxBp(n_phi_max+1,nThetaB)=0.0_cp
               this%VxBp(n_phi_max+2,nThetaB)=0.0_cp
            end do

         else if ( nBc == 2 ) then  ! rigid boundary :

            !----- Only vp /= 0 at boundary allowed (rotation of boundaries about z-axis):
            nTheta=nThetaLast
            do nThetaB=1,sizeThetaB
               nTheta   =nTheta+1
               nThetaNHS=(nTheta+1)/2
               or4sn2   =or4(nR)*osn2(nThetaNHS)
               do nPhi=1,n_phi_max
                  this%VxBt(nPhi,nThetaB)= or4sn2 * orho1(nR) * &
                  &    this%vpc(nPhi,nThetaB)*this%brc(nPhi,nThetaB)
                  this%VxBp(nPhi,nThetaB)= 0.0_cp
               end do
               this%VxBt(n_phi_max+1,nThetaB)=0.0_cp
               this%VxBt(n_phi_max+2,nThetaB)=0.0_cp
               this%VxBp(n_phi_max+1,nThetaB)=0.0_cp
               this%VxBp(n_phi_max+2,nThetaB)=0.0_cp
            end do

         end if  ! boundary ?

      end if ! l_mag_nl ?

      if ( l_anel .and. nBc == 0 ) then
         !------ Get viscous heating
         nTheta=nThetaLast
         do nThetaB=1,sizeThetaB ! loop over theta points in block
            nTheta   =nTheta+1
            nThetaNHS=(nTheta+1)/2
            csn2     =cosn2(nThetaNHS)
            if ( mod(nTheta,2) == 0 ) csn2=-csn2 ! South, odd function in theta

            do nPhi=1,n_phi_max
               this%ViscHeat(nPhi,nThetaB)=      or4(nR)*                  &
               &                     orho1(nR)*otemp1(nR)*visc(nR)*(       &
               &     two*(                     this%dvrdrc(nPhi,nThetaB) - & ! (1)
               &     (two*or1(nR)+beta(nR))*this%vrc(nphi,nThetaB) )**2  + &
               &     two*( csn2*                  this%vtc(nPhi,nThetaB) + &
               &                               this%dvpdpc(nphi,nThetaB) + &
               &                               this%dvrdrc(nPhi,nThetaB) - & ! (2)
               &     or1(nR)*               this%vrc(nPhi,nThetaB) )**2  + &
               &     two*(                     this%dvpdpc(nphi,nThetaB) + &
               &           csn2*                  this%vtc(nPhi,nThetaB) + & ! (3)
               &     or1(nR)*               this%vrc(nPhi,nThetaB) )**2  + &
               &          ( two*               this%dvtdpc(nPhi,nThetaB) + &
               &                                 this%cvrc(nPhi,nThetaB) - & ! (6)
               &      two*csn2*             this%vpc(nPhi,nThetaB) )**2  + &
               &                                 osn2(nThetaNHS) * (       &
               &         ( r(nR)*              this%dvtdrc(nPhi,nThetaB) - &
               &           (two+beta(nR)*r(nR))*  this%vtc(nPhi,nThetaB) + & ! (4)
               &     or1(nR)*            this%dvrdtc(nPhi,nThetaB) )**2  + &
               &         ( r(nR)*              this%dvpdrc(nPhi,nThetaB) - &
               &           (two+beta(nR)*r(nR))*  this%vpc(nPhi,nThetaB) + & ! (5)
               &     or1(nR)*            this%dvrdpc(nPhi,nThetaB) )**2 )- &
               &    two*third*(  beta(nR)*        this%vrc(nPhi,nThetaB) )**2 )
            end do
            this%ViscHeat(n_phi_max+1,nThetaB)=0.0_cp
            this%ViscHeat(n_phi_max+2,nThetaB)=0.0_cp
         end do ! theta loop

         if ( l_mag_nl .and. nR>n_r_LCR ) then
            !------ Get ohmic losses
            nTheta=nThetaLast
            do nThetaB=1,sizeThetaB ! loop over theta points in block
               nTheta   =nTheta+1
               nThetaNHS=(nTheta+1)/2
               do nPhi=1,n_phi_max
                  this%OhmLoss(nPhi,nThetaB)= or2(nR)*otemp1(nR)*lambda(nR)*  &
                  &    ( or2(nR)*                this%cbrc(nPhi,nThetaB)**2 + &
                  &      osn2(nThetaNHS)*        this%cbtc(nPhi,nThetaB)**2 + &
                  &      osn2(nThetaNHS)*        this%cbpc(nPhi,nThetaB)**2  )
               end do
               this%OhmLoss(n_phi_max+1,nThetaB)=0.0_cp
               this%OhmLoss(n_phi_max+2,nThetaB)=0.0_cp
            end do ! theta loop

         end if ! if l_mag_nl ?

      end if  ! Viscous heating and Ohmic losses ?

      if ( lRmsCalc ) then
         nTheta=nThetaLast
         do nThetaB=1,sizeThetaB ! loop over theta points in block
            nTheta   =nTheta+1
            snt=sinTheta(nTheta)
            cnt=cosTheta(nTheta)
            rsnt=r(nR)*snt
            do nPhi=1,n_phi_max
               this%dpdtc(nPhi,nThetaB)=this%dpdtc(nPhi,nThetaB)/r(nR)/snt/snt
               this%dpdpc(nPhi,nThetaB)=this%dpdpc(nPhi,nThetaB)/r(nR)/snt/snt
               this%CFt2(nPhi,nThetaB)=-2*CorFac *cnt*this%vpc(nPhi,nThetaB)/rsnt/snt
               this%CFp2(nPhi,nThetaB)=2*CorFac * (                      &
               &                     cnt*this%vtc(nPhi,nThetaB)/rsnt +   &
               &                     or2(nR)*snt*this%vrc(nPhi,nThetaB) )/snt
               if ( l_conv_nl ) then
                  this%Advt2(nPhi,nThetaB)=r(nR)*this%Advt(nPhi,nThetaB)
                  this%Advp2(nPhi,nThetaB)=r(nR)*this%Advp(nPhi,nThetaB)
               end if
               if ( l_mag_LF .and. nR > n_r_LCR ) then
                  this%LFt2(nPhi,nThetaB)=r(nR)*this%LFt(nPhi,nThetaB)
                  this%LFp2(nPhi,nThetaB)=r(nR)*this%LFp(nPhi,nThetaB)
               end if
               this%dpdtc(n_phi_max+1,nThetaB)=0.0_cp
               this%dpdtc(n_phi_max+2,nThetaB)=0.0_cp
               this%dpdpc(n_phi_max+1,nThetaB)=0.0_cp
               this%dpdpc(n_phi_max+2,nThetaB)=0.0_cp
               this%CFt2(n_phi_max+1,nThetaB)=0.0_cp
               this%CFt2(n_phi_max+2,nThetaB)=0.0_cp
               this%CFp2(n_phi_max+1,nThetaB)=0.0_cp
               this%CFp2(n_phi_max+2,nThetaB)=0.0_cp
               if ( l_conv_nl ) then
                  this%Advt2(n_phi_max+1,nThetaB)=0.0_cp
                  this%Advt2(n_phi_max+2,nThetaB)=0.0_cp
                  this%Advp2(n_phi_max+1,nThetaB)=0.0_cp
                  this%Advp2(n_phi_max+2,nThetaB)=0.0_cp
               end if
               if ( l_mag_nl .and. nR > n_r_LCR ) then
                  this%LFt2(n_phi_max+1,nThetaB)=0.0_cp
                  this%LFt2(n_phi_max+2,nThetaB)=0.0_cp
                  this%LFp2(n_phi_max+1,nThetaB)=0.0_cp
                  this%LFp2(n_phi_max+2,nThetaB)=0.0_cp
               end if
            end do
         end do
      end if

   end subroutine get_nl
!----------------------------------------------------------------------------
end module grid_space_arrays_mod

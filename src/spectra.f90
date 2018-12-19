module spectra

   use parallel_mod
   use precision_mod
   use mem_alloc, only: bytes_allocated
   use geometry, only: n_r_max, n_r_ic_maxMag, n_r_maxMag, &
       &               n_r_ic_max, l_max, minc, n_r_cmb, n_r_icb
   use radial_functions, only: orho1, orho2, r_ic, chebt_ic, r,   &
       &                       rscheme_oc, or2, r_icb, dr_fac_ic
   use physical_parameters, only: LFfac
   use num_param, only: eScale, tScale
   use blocking, only: lo_map
   use horizontal_data, only: dLh
   use logic, only: l_mag, l_anel, l_cond_ic, l_heat, l_save_out, &
       &            l_energy_modes
   use output_data, only: tag, log_file, n_log_file, m_max_modes
   use LMLoop_data,only: llm, ulm, llmMag, ulmMag
   use useful, only: cc2real, cc22real, abortRun, get_mean_sd
   use integration, only: rInt_R, rIntIC
   use constants, only: pi, vol_oc, half, one, four
   use LMmapping, only: map_glbl_st

   implicit none
  
   private
 
   real(cp), allocatable :: e_p_l_ave(:), e_p_m_ave(:)
   real(cp), allocatable :: e_p_l_SD(:), e_p_m_SD(:)
   real(cp), allocatable :: e_t_l_ave(:), e_t_m_ave(:)
   real(cp), allocatable :: e_t_l_SD(:), e_t_m_SD(:)
   real(cp), allocatable :: e_cmb_l_ave(:), e_cmb_m_ave(:)
   real(cp), allocatable :: e_cmb_l_SD(:), e_cmb_m_SD(:)
 
   real(cp), allocatable :: ek_p_l_ave(:), ek_p_m_ave(:)
   real(cp), allocatable :: ek_p_l_SD(:), ek_p_m_SD(:)
   real(cp), allocatable :: ek_t_l_ave(:), ek_t_m_ave(:)
   real(cp), allocatable :: ek_t_l_SD(:), ek_t_m_SD(:)

   real(cp), allocatable :: T_l_ave(:), T_ICB_l_ave(:), dT_ICB_l_ave(:)
   real(cp), allocatable :: T_l_SD(:), T_ICB_l_SD(:), dT_ICB_l_SD(:)
   real(cp), allocatable :: T_m_ave(:), T_ICB_m_ave(:), dT_ICB_m_ave(:)
   real(cp), allocatable :: T_m_SD(:), T_ICB_m_SD(:), dT_ICB_m_SD(:)

   integer :: n_kin_spec_file, n_u2_spec_file, n_mag_spec_file
   integer :: n_temp_spec_file
   integer :: n_am_kpol_file, n_am_ktor_file
   integer :: n_am_mpol_file, n_am_mtor_file
   character(len=72) :: am_kpol_file, am_ktor_file
   character(len=72) :: am_mpol_file, am_mtor_file

 
   public :: initialize_spectra, spectrum, spectrum_average,     &
   &         spectrum_temp, get_amplitude, finalize_spectra

contains

   subroutine initialize_spectra

      allocate( e_p_l_ave(0:l_max),e_p_m_ave(0:l_max) )
      allocate( e_p_l_SD(0:l_max),e_p_m_SD(0:l_max) )
      allocate( e_t_l_ave(0:l_max),e_t_m_ave(0:l_max) )
      allocate( e_t_l_SD(0:l_max),e_t_m_SD(0:l_max) )
      allocate( e_cmb_l_ave(0:l_max),e_cmb_m_ave(0:l_max) )
      allocate( e_cmb_l_SD(0:l_max),e_cmb_m_SD(0:l_max) )

      allocate( ek_p_l_ave(0:l_max),ek_p_m_ave(0:l_max) )
      allocate( ek_p_l_SD(0:l_max),ek_p_m_SD(0:l_max) )
      allocate( ek_t_l_ave(0:l_max),ek_t_m_ave(0:l_max) )
      allocate( ek_t_l_SD(0:l_max),ek_t_m_SD(0:l_max) )
      bytes_allocated = bytes_allocated+20*(l_max+1)*SIZEOF_DEF_REAL

      if ( l_heat ) then
         allocate( T_l_ave(l_max+1), T_ICB_l_ave(l_max+1), dT_ICB_l_ave(l_max+1) )
         allocate( T_l_SD(l_max+1), T_ICB_l_SD(l_max+1), dT_ICB_l_SD(l_max+1) )
         allocate( T_m_ave(l_max+1), T_ICB_m_ave(l_max+1), dT_ICB_m_ave(l_max+1) )
         allocate( T_m_SD(l_max+1), T_ICB_m_SD(l_max+1), dT_ICB_m_SD(l_max+1) )
         bytes_allocated = bytes_allocated+12*(l_max+1)*SIZEOF_DEF_REAL
      end if

      am_kpol_file='am_kin_pol.'//tag
      am_ktor_file='am_kin_tor.'//tag
      am_mpol_file='am_mag_pol.'//tag
      am_mtor_file='am_mag_tor.'//tag

      if ( rank == 0 .and. (.not. l_save_out) ) then
         if ( l_mag .and. l_energy_modes ) then
            open(newunit=n_am_kpol_file,file=am_kpol_file,status='new', &
            &    form='unformatted')
            open(newunit=n_am_ktor_file,file=am_ktor_file,status='new', &
            &    form='unformatted')
            open(newunit=n_am_mpol_file,file=am_mpol_file,status='new', &
            &    form='unformatted')
            open(newunit=n_am_mtor_file,file=am_mtor_file,status='new', &
            &    form='unformatted')
         end if
      end if

   end subroutine initialize_spectra
!----------------------------------------------------------------------------
   subroutine finalize_spectra

      deallocate( e_p_l_ave, e_p_m_ave, e_p_l_SD, e_p_m_SD )
      deallocate( e_t_l_ave, e_t_m_ave, e_t_l_SD, e_t_m_SD )
      deallocate( e_cmb_l_ave, e_cmb_m_ave, e_cmb_l_SD, e_cmb_m_SD )
      deallocate( ek_p_l_ave, ek_p_m_ave, ek_p_l_SD, ek_p_m_SD )
      deallocate( ek_t_l_ave, ek_t_m_ave, ek_t_l_SD, ek_t_m_SD )

      if ( l_heat ) then
         deallocate( T_l_ave, T_ICB_l_ave, dT_ICB_l_ave )
         deallocate( T_l_SD, T_ICB_l_SD, dT_ICB_l_SD )
         deallocate( T_m_ave, T_ICB_m_ave, dT_ICB_m_ave )
         deallocate( T_m_SD, T_ICB_m_SD, dT_ICB_m_SD )
      end if

      if ( rank == 0 .and. (.not. l_save_out) ) then
         if ( l_mag .and. l_energy_modes ) then
            close(n_am_kpol_file)
            close(n_am_ktor_file)
            close(n_am_mpol_file)
            close(n_am_mtor_file)
         end if
      end if

   end subroutine finalize_spectra
!----------------------------------------------------------------------------
   subroutine spectrum_average(n_time_ave,l_stop_time,time_passed,time_norm, &
              &                b,aj,db,BV)

      !-- Input variables:
      integer,          intent(in) :: n_time_ave
      logical,          intent(in) :: l_stop_time
      real(cp),         intent(in) :: time_passed
      real(cp),         intent(in) :: time_norm
      complex(cp),      intent(in) :: b(llm:ulm,n_r_max)
      complex(cp),      intent(in) :: aj(llm:ulm,n_r_max)
      complex(cp),      intent(in) :: db(llm:ulm,n_r_max)
      character(len=1), intent(in) :: BV

      !-- Output variables: 
      real(cp) :: e_p_l(0:l_max),e_t_l(0:l_max)
      real(cp) :: e_cmb_l(0:l_max)
      real(cp) :: e_p_m(0:l_max),e_t_m(0:l_max)
      real(cp) :: e_cmb_m(0:l_max)

      !-- Local variables:
      character(len=85) :: outFile
      integer :: nOut
      integer :: nR,lm,l,m,ierr

      real(cp) :: e_p_temp,e_t_temp
      real(cp) :: fac

      real(cp) :: e_p_r_l(n_r_max,0:l_max),e_p_r_l_global(n_r_max,0:l_max)
      real(cp) :: e_t_r_l(n_r_max,0:l_max),e_t_r_l_global(n_r_max,0:l_max)
      real(cp) :: e_p_r_m(n_r_max,0:l_max),e_p_r_m_global(n_r_max,0:l_max)
      real(cp) :: e_t_r_m(n_r_max,0:l_max),e_t_r_m_global(n_r_max,0:l_max)

      if ( BV == 'V' ) then ! kinetic spectrum (correction of density)

         do nR=1,n_r_max
            do l=0,l_max
               e_p_r_l(nR,l)=0.0_cp
               e_t_r_l(nR,l)=0.0_cp
               e_p_r_m(nR,l)=0.0_cp
               e_t_r_m(nR,l)=0.0_cp
            end do
            !do lm=2,lm_max
            do lm=max(llm,2),ulm
               l =lo_map%lm2l(lm)
               m =lo_map%lm2m(lm)
               e_p_temp= orho1(nR) * dLh(map_glbl_st%lm2(l,m)) * (             &
               &         dLh(map_glbl_st%lm2(l,m))*or2(nR)*cc2real(b(lm,nR),m) &
               &         + cc2real(db(lm,nR),m) )
               e_t_temp=orho1(nR)*dLh(map_glbl_st%lm2(l,m))*cc2real(aj(lm,nR),m)
               e_p_r_l(nR,l)=e_p_r_l(nR,l)+e_p_temp
               e_t_r_l(nR,l)=e_t_r_l(nR,l)+e_t_temp
               e_p_r_m(nR,m)=e_p_r_m(nR,m)+e_p_temp
               e_t_r_m(nR,m)=e_t_r_m(nR,m)+e_t_temp
            end do    ! do loop over lms in block 
         end do    ! radial grid points

      else ! magnetic spectrum

         do nR=1,n_r_max
            do l=0,l_max
               e_p_r_l(nR,l)=0.0_cp
               e_t_r_l(nR,l)=0.0_cp
               e_p_r_m(nR,l)=0.0_cp
               e_t_r_m(nR,l)=0.0_cp
            end do
            do lm=max(2,llm),ulm
               l =lo_map%lm2l(lm)
               m =lo_map%lm2m(lm)
               e_p_temp=  dLh(map_glbl_st%lm2(l,m)) * (                           &
               &            dLh(map_glbl_st%lm2(l,m))*or2(nR)*cc2real(b(lm,nR),m) &
               &            + cc2real(db(lm,nR),m) )
               e_t_temp=dLh(map_glbl_st%lm2(l,m))*cc2real(aj(lm,nR),m)
               e_p_r_l(nR,l)=e_p_r_l(nR,l)+e_p_temp
               e_t_r_l(nR,l)=e_t_r_l(nR,l)+e_t_temp
               e_p_r_m(nR,m)=e_p_r_m(nR,m)+e_p_temp
               e_t_r_m(nR,m)=e_t_r_m(nR,m)+e_t_temp
            end do    ! do loop over lms in block 
         end do    ! radial grid points

      end if

#ifdef WITH_MPI
      call MPI_Reduce(e_p_r_l,e_p_r_l_global,n_r_max*(l_max+1),    &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(e_t_r_l,e_t_r_l_global,n_r_max*(l_max+1),    &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(e_p_r_m,e_p_r_m_global,n_r_max*(l_max+1),    &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(e_t_r_m,e_t_r_m_global,n_r_max*(l_max+1),    &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
#else
      e_p_r_l_global(:,:)=e_p_r_l(:,:)
      e_t_r_l_global(:,:)=e_t_r_l(:,:)
      e_p_r_m_global(:,:)=e_p_r_m(:,:)
      e_t_r_m_global(:,:)=e_t_r_m(:,:)
#endif

      if ( coord_r == 0 ) then
         !-- Radial Integrals:
         fac=half*eScale
         if ( BV == 'B' ) fac=fac*LFfac
         do l=0,l_max
            e_p_l(l)  =fac*rInt_R(e_p_r_l_global(:,l),r,rscheme_oc)
            e_t_l(l)  =fac*rInt_R(e_t_r_l_global(:,l),r,rscheme_oc)
            e_p_m(l)  =fac*rInt_R(e_p_r_m_global(:,l),r,rscheme_oc)
            e_t_m(l)  =fac*rInt_R(e_t_r_m_global(:,l),r,rscheme_oc)
            if ( BV == 'B' ) then 
               e_cmb_l(l)=fac*e_p_r_l_global(1,l)
               e_cmb_m(l)=fac*e_p_r_m_global(1,l)
            end if
         end do

         !-- Averaging:
         if ( BV == 'B' ) then
            call get_mean_sd(e_p_l_ave, e_p_l_SD, e_p_l, n_time_ave, time_passed, &
                 &           time_norm)
            call get_mean_sd(e_t_l_ave, e_t_l_SD, e_t_l, n_time_ave, time_passed, &
                 &           time_norm)
            call get_mean_sd(e_p_m_ave, e_p_m_SD, e_p_m, n_time_ave, time_passed, &
                 &           time_norm)
            call get_mean_sd(e_t_m_ave, e_t_m_SD, e_t_m, n_time_ave, time_passed, &
                 &           time_norm)
            call get_mean_sd(e_cmb_l_ave, e_cmb_l_SD, e_cmb_l, n_time_ave, &
                 &           time_passed, time_norm)
            call get_mean_sd(e_cmb_m_ave, e_cmb_m_SD, e_cmb_m, n_time_ave, &
                 &           time_passed, time_norm)
         else
            call get_mean_sd(ek_p_l_ave, ek_p_l_SD, e_p_l, n_time_ave, time_passed,&
                 &           time_norm)
            call get_mean_sd(ek_t_l_ave, ek_t_l_SD, e_t_l, n_time_ave, time_passed,&
                 &           time_norm)
            call get_mean_sd(ek_p_m_ave, ek_p_m_SD, e_p_m, n_time_ave, time_passed,&
                 &           time_norm)
            call get_mean_sd(ek_t_m_ave, ek_t_m_SD, e_t_m, n_time_ave, time_passed,&
                 &           time_norm)

         end if

         !-- Output: every 10th averaging step and at end of run
         if ( l_stop_time .or. mod(n_time_ave,10) == 0 ) then

            !------ Output:
            if ( BV == 'B' ) then
               outFile='mag_spec_ave.'//tag
            else if ( BV == 'V' ) then
               outFile='kin_spec_ave.'//tag
            else
               call abortRun('Wrong BV input to spectrum_average!')
            end if

            open(newunit=nOut, file=outFile, status='unknown')
            if ( BV == 'B' ) then
               e_p_l_SD(:)  =sqrt(e_p_l_SD(:)/time_norm)
               e_t_l_SD(:)  =sqrt(e_t_l_SD(:)/time_norm)
               e_p_m_SD(:)  =sqrt(e_p_m_SD(:)/time_norm)
               e_t_m_SD(:)  =sqrt(e_t_m_SD(:)/time_norm)
               e_cmb_l_SD(:)=sqrt(e_cmb_l_SD(:)/time_norm)
               e_cmb_m_SD(:)=sqrt(e_cmb_m_SD(:)/time_norm)
               do l=0,l_max
                  write(nOut,'(2X,1P,I4,12ES16.8)') l, e_p_l_ave(l), e_p_m_ave(l), &
                  &                                    e_t_l_ave(l), e_t_m_ave(l), &
                  &                                e_cmb_l_ave(l), e_cmb_m_ave(l), &
                  &                                      e_p_l_SD(l), e_p_m_SD(l), &
                  &                                      e_t_l_SD(l), e_t_m_SD(l), &
                  &                                  e_cmb_l_SD(l), e_cmb_m_SD(l)
               end do
            else
               do l=0,l_max
                  write(nOut,'(2X,1P,I4,8ES16.8)') l,ek_p_l_ave(l), ek_p_m_ave(l), &
                  &                                  ek_t_l_ave(l), ek_t_m_ave(l), &
                  &                                    ek_p_l_SD(l), ek_p_m_SD(l), &
                  &                                    ek_t_l_SD(l), ek_t_m_SD(l)
               end do
            end if
            close(nOut)

            if ( l_stop_time ) then
               if ( l_save_out ) then
                  open(newunit=n_log_file, file=log_file, status='unknown', &
                  &    position='append')
               end if
               write(n_log_file,"(/,A,A)")                        &
               &     ' ! TIME AVERAGED SPECTRA STORED IN FILE: ', &
               &      outFile
               write(n_log_file,"(A,I5)")                         &
               &     ' !              No. of averaged spectra: ', &
               &     n_time_ave
               if ( l_save_out ) close(n_log_file)
            end if

         end if
      end if

   end subroutine spectrum_average
!----------------------------------------------------------------------------
   subroutine spectrum(time,n_spec,w,dw,z,b,db,aj,b_ic,db_ic,aj_ic)
      !
      !  calculates magnetic energy  = 1/2 Integral(B^2 dV)
      !  integration in theta,phi by summation over harmonic coeffs.
      !  integration in r by Chebycheff integrals
      !
      !  Output:
      !  enbp: Total poloidal        enbt: Total toroidal
      !  apome: Axisym. poloidal     atome: Axisym. toroidal
      !
    
      !-- Input of variables:
      integer,     intent(in) :: n_spec     ! number of spectrum/call, file
      real(cp),    intent(in) :: time
      complex(cp), intent(in) :: w(llm:ulm,n_r_max)
      complex(cp), intent(in) :: dw(llm:ulm,n_r_max)
      complex(cp), intent(in) :: z(llm:ulm,n_r_max)
      complex(cp), intent(in) :: b(llmMag:ulmMag,n_r_maxMag)
      complex(cp), intent(in) :: db(llmMag:ulmMag,n_r_maxMag)
      complex(cp), intent(in) :: aj(llmMag:ulmMag,n_r_maxMag)
      complex(cp), intent(in) :: b_ic(llmMag:ulmMag,n_r_ic_maxMag)
      complex(cp), intent(in) :: db_ic(llmMag:ulmMag,n_r_ic_maxMag)
      complex(cp), intent(in) :: aj_ic(llmMag:ulmMag,n_r_ic_maxMag)
    
      !-- Output:
      real(cp) :: b_rms
      real(cp) :: e_mag_p_l(l_max),e_mag_t_l(l_max)
      real(cp) :: e_kin_p_l(l_max),e_kin_t_l(l_max)
      real(cp) :: e_mag_p_ic_l(l_max),e_mag_t_ic_l(l_max)
      real(cp) :: u2_p_l(l_max),u2_t_l(l_max)
    
      real(cp) :: e_mag_p_m(l_max+1),e_mag_t_m(l_max+1)
      real(cp) :: e_kin_p_m(l_max+1),e_kin_t_m(l_max+1)
      real(cp) :: e_mag_p_ic_m(l_max+1),e_mag_t_ic_m(l_max+1)
      real(cp) :: u2_p_m(l_max+1),u2_t_m(l_max+1)
    
      real(cp) :: e_mag_cmb_l(l_max)
      real(cp) :: e_mag_cmb_m(l_max+1)
      real(cp) :: e_kin_nearSurf_l(l_max)
      real(cp) :: e_kin_nearSurf_m(l_max+1)
    
      real(cp) :: eCMB(l_max),eCMB_global(l_max)
    
      !-- local:
      character(len=14) :: string
      character(len=72) :: mag_spec_file,kin_spec_file,u2_spec_file
      integer :: n_r,lm,ml,l,mc,m,n_const
    
      real(cp) :: r_ratio,O_r_icb_E_2
      real(cp) :: e_mag_p_temp,e_mag_t_temp
      real(cp) :: e_kin_p_temp,e_kin_t_temp
      real(cp) :: u2_p_temp,u2_t_temp
      real(cp) :: O_surface
      real(cp) :: fac_mag,fac_kin
      real(cp) :: nearSurfR
    
      real(cp) :: e_mag_p_r_l(n_r_max,l_max),e_mag_p_r_l_global(n_r_max,l_max)
      real(cp) :: e_mag_t_r_l(n_r_max,l_max),e_mag_t_r_l_global(n_r_max,l_max)
      real(cp) :: e_kin_p_r_l(n_r_max,l_max),e_kin_p_r_l_global(n_r_max,l_max)
      real(cp) :: e_kin_t_r_l(n_r_max,l_max),e_kin_t_r_l_global(n_r_max,l_max)
      real(cp) :: u2_p_r_l(n_r_max,l_max),u2_p_r_l_global(n_r_max,l_max)
      real(cp) :: u2_t_r_l(n_r_max,l_max),u2_t_r_l_global(n_r_max,l_max)
      real(cp) :: e_mag_p_r_m(n_r_max,l_max+1),e_mag_p_r_m_global(n_r_max,l_max+1)
      real(cp) :: e_mag_t_r_m(n_r_max,l_max+1),e_mag_t_r_m_global(n_r_max,l_max+1)
      real(cp) :: e_kin_p_r_m(n_r_max,l_max+1),e_kin_p_r_m_global(n_r_max,l_max+1)
      real(cp) :: e_kin_t_r_m(n_r_max,l_max+1),e_kin_t_r_m_global(n_r_max,l_max+1)
      real(cp) :: u2_p_r_m(n_r_max,l_max+1),u2_p_r_m_global(n_r_max,l_max+1)
      real(cp) :: u2_t_r_m(n_r_max,l_max+1),u2_t_r_m_global(n_r_max,l_max+1)
    
      real(cp) :: e_mag_p_ic_r_l(n_r_ic_max,l_max)
      real(cp) :: e_mag_p_ic_r_l_global(n_r_ic_max,l_max)
      real(cp) :: e_mag_t_ic_r_l(n_r_ic_max,l_max)
      real(cp) :: e_mag_t_ic_r_l_global(n_r_ic_max,l_max)
      real(cp) :: e_mag_p_ic_r_m(n_r_ic_max,l_max+1)
      real(cp) :: e_mag_p_ic_r_m_global(n_r_ic_max,l_max+1)
      real(cp) :: e_mag_t_ic_r_m(n_r_ic_max,l_max+1)
      real(cp) :: e_mag_t_ic_r_m_global(n_r_ic_max,l_max+1)
    
      complex(cp) :: r_dr_b
    
    
      eCMB(:)=0.0_cp
    
      do n_r=1,n_r_max
    
         do l=1,l_max
            if ( l_mag ) then
               e_mag_p_r_l(n_r,l)=0.0_cp
               e_mag_t_r_l(n_r,l)=0.0_cp
            end if
            if ( l_anel ) then
               u2_p_r_l(n_r,l)=0.0_cp
               u2_t_r_l(n_r,l)=0.0_cp
            end if
            e_kin_p_r_l(n_r,l)=0.0_cp
            e_kin_t_r_l(n_r,l)=0.0_cp
         end do
         do mc=1,l_max+1
            if ( l_mag ) then
               e_mag_p_r_m(n_r,mc)=0.0_cp
               e_mag_t_r_m(n_r,mc)=0.0_cp
            end if
            if ( l_anel ) then
               u2_p_r_m(n_r,mc)=0.0_cp
               u2_t_r_m(n_r,mc)=0.0_cp
            end if
            e_kin_p_r_m(n_r,mc)=0.0_cp
            e_kin_t_r_m(n_r,mc)=0.0_cp
         end do
    
         !do lm=2,lm_max
         do lm=max(llm,2),ulm
    
            l  =lo_map%lm2l(lm)
            m  =lo_map%lm2m(lm)
            mc=m+1
    
            if ( l_mag ) then
               e_mag_p_temp= dLh(map_glbl_st%lm2(l,m)) * ( dLh(map_glbl_st%lm2(l,m))*     &
               &             or2(n_r)*cc2real(b(lm,n_r),m) + cc2real(db(lm,n_r),m) )
               e_mag_t_temp=dLh(map_glbl_st%lm2(l,m))*cc2real(aj(lm,n_r),m)
            end if
            if ( l_anel ) then
               u2_p_temp=  orho2(n_r)*dLh(map_glbl_st%lm2(l,m)) *  (                   &
               &             dLh(map_glbl_st%lm2(l,m))*or2(n_r)*cc2real(w(lm,n_r),m) + &
               &             cc2real(dw(lm,n_r),m) )
               u2_t_temp=orho2(n_r)*dLh(map_glbl_st%lm2(l,m))*cc2real(z(lm,n_r),m)
            end if
            e_kin_p_temp= orho1(n_r)*dLh(map_glbl_st%lm2(l,m)) *  (                   &
            &               dLh(map_glbl_st%lm2(l,m))*or2(n_r)*cc2real(w(lm,n_r),m) + &
            &               cc2real(dw(lm,n_r),m) )
            e_kin_t_temp=orho1(n_r)*dLh(map_glbl_st%lm2(l,m))*cc2real(z(lm,n_r),m)
    
            !----- l-spectra:
            if ( l_mag ) then
               e_mag_p_r_l(n_r,l) = e_mag_p_r_l(n_r,l) + e_mag_p_temp
               e_mag_t_r_l(n_r,l) = e_mag_t_r_l(n_r,l) + e_mag_t_temp
               if ( m == 0 .and. n_r == n_r_cmb ) eCMB(l)=e_mag_p_temp
            end if
            if ( l_anel ) then
               u2_p_r_l(n_r,l) = u2_p_r_l(n_r,l) + u2_p_temp
               u2_t_r_l(n_r,l) = u2_t_r_l(n_r,l) + u2_t_temp
            end if
            e_kin_p_r_l(n_r,l) = e_kin_p_r_l(n_r,l) + e_kin_p_temp
            e_kin_t_r_l(n_r,l) = e_kin_t_r_l(n_r,l) + e_kin_t_temp
    
            !----- m-spectra:
            if ( l_mag ) then
               e_mag_p_r_m(n_r,mc) = e_mag_p_r_m(n_r,mc) + e_mag_p_temp
               e_mag_t_r_m(n_r,mc) = e_mag_t_r_m(n_r,mc) + e_mag_t_temp
            end if
            if ( l_anel ) then
               u2_p_r_m(n_r,mc) = u2_p_r_m(n_r,mc) + u2_p_temp
               u2_t_r_m(n_r,mc) = u2_t_r_m(n_r,mc) + u2_t_temp
            end if
            e_kin_p_r_m(n_r,mc)=e_kin_p_r_m(n_r,mc) + e_kin_p_temp
            e_kin_t_r_m(n_r,mc)=e_kin_t_r_m(n_r,mc) + e_kin_t_temp
    
         end do    ! do loop over lms in block
    
      end do    ! radial grid points
    
      ! ----------- We need a reduction here ----------------
      ! first the l-spectra
#ifdef WITH_MPI
      if ( l_mag ) then
         call MPI_Reduce(e_mag_p_r_l, e_mag_p_r_l_global, n_r_max*l_max,&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
         call MPI_Reduce(e_mag_t_r_l, e_mag_t_r_l_global, n_r_max*l_max,&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      end if
      if ( l_anel ) then
         call MPI_Reduce(u2_p_r_l, u2_p_r_l_global, n_r_max*l_max,   &
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
         call MPI_Reduce(u2_t_r_l, u2_t_r_l_global, n_r_max*l_max,   &
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      end if
      call MPI_Reduce(e_kin_p_r_l, e_kin_p_r_l_global, n_r_max*l_max,&
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(e_kin_t_r_l, e_kin_t_r_l_global, n_r_max*l_max,&
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
    
      ! then the m-spectra
      if ( l_mag ) then
         call MPI_Reduce(e_mag_p_r_m, e_mag_p_r_m_global, n_r_max*(l_max+1),&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
         call MPI_Reduce(e_mag_t_r_m, e_mag_t_r_m_global, n_r_max*(l_max+1),&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
         call MPI_Reduce(eCMB, eCMB_global,l_max,MPI_DEF_REAL,MPI_SUM,0, &
              &          comm_r,ierr)
      end if
      if ( l_anel ) then
         call MPI_Reduce(u2_p_r_m, u2_p_r_m_global, n_r_max*(l_max+1),&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
         call MPI_Reduce(u2_t_r_m, u2_t_r_m_global, n_r_max*(l_max+1),&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      end if
      call MPI_Reduce(e_kin_p_r_m, e_kin_p_r_m_global, n_r_max*(l_max+1),  &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(e_kin_t_r_m, e_kin_t_r_m_global, n_r_max*(l_max+1),  &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
#else
      if ( l_mag ) then
         e_mag_p_r_l_global(:,:)=e_mag_p_r_l(:,:)
         e_mag_t_r_l_global(:,:)=e_mag_t_r_l(:,:)
         e_mag_p_r_m_global(:,:)=e_mag_p_r_m(:,:)
         e_mag_t_r_m_global(:,:)=e_mag_t_r_m(:,:)
         eCMB_global(:)         =eCMB(:)
      end if
      if ( l_anel ) then
         u2_p_r_l_global(:,:)=u2_p_r_l(:,:)
         u2_t_r_l_global(:,:)=u2_t_r_l(:,:)
         u2_p_r_m_global(:,:)=u2_p_r_m(:,:)
         u2_t_r_m_global(:,:)=u2_t_r_m(:,:)
      end if
      e_kin_p_r_l_global(:,:)=e_kin_p_r_l(:,:)
      e_kin_t_r_l_global(:,:)=e_kin_t_r_l(:,:)
      e_kin_p_r_m_global(:,:)=e_kin_p_r_m(:,:)
      e_kin_t_r_m_global(:,:)=e_kin_t_r_m(:,:)
#endif
    
      ! now switch to coord_r 0 for the postprocess
      
    
      ! Getting appropriate radius index for e_kin_nearSurf spectra
      nearSurfR = r_icb+0.99_cp
      do n_r=2,n_r_max
         if ( r(n_r-1) > nearSurfR .and. r(n_r)  <= nearSurfR ) then
            if ( r(n_r-1)-nearSurfR < nearSurfR-r(n_r) ) then
               n_const=n_r-1
            else
               n_const=n_r
            end if
         end if
      end do
    
      if ( coord_r == 0 ) then
         !-- Save CMB energy spectra:
         O_surface=one/(four*pi*r(1)*r(1))
    
         if ( l_mag ) then
            b_rms=0.0_cp
            do l=1,l_max
               e_mag_cmb_l(l)=e_mag_p_r_l_global(1,l)
               b_rms=b_rms + e_mag_cmb_l(l)
            end do
            b_rms=sqrt(b_rms*O_surface)
            do mc=1,l_max+1
               e_mag_cmb_m(mc)=e_mag_p_r_m_global(1,mc)
            end do
         end if
    
         !-- Save nearSurf kin energy spectra:
         do l=1,l_max
            e_kin_nearSurf_l(l)=e_kin_p_r_l_global(n_const,l)
         end do
         do mc=1,l_max+1
            e_kin_nearSurf_m(mc)=e_kin_p_r_m_global(n_const,mc)
         end do
    
         !-- Radial Integrals:
         fac_mag=half*LFfac*eScale
         fac_kin=half*eScale
         do l=1,l_max
            if ( l_mag ) then
               e_mag_p_l(l)=fac_mag*rInt_R(e_mag_p_r_l_global(:,l),r,rscheme_oc)
               e_mag_t_l(l)=fac_mag*rInt_R(e_mag_t_r_l_global(:,l),r,rscheme_oc)
               e_mag_cmb_l(l)=fac_mag*e_mag_cmb_l(l)
            end if
            if ( l_anel ) then
               u2_p_l(l)  =fac_kin*rInt_R(u2_p_r_l_global(:,l),r,rscheme_oc)
               u2_t_l(l)  =fac_kin*rInt_R(u2_t_r_l_global(:,l),r,rscheme_oc)
            end if
            e_kin_p_l(l)  =fac_kin*rInt_R(e_kin_p_r_l_global(:,l),r,rscheme_oc)
            e_kin_t_l(l)  =fac_kin*rInt_R(e_kin_t_r_l_global(:,l),r,rscheme_oc)
            e_kin_nearSurf_l(l)=fac_kin*e_kin_nearSurf_l(l)
         end do
         do m=1,l_max+1 ! Note: counter m is actual order+1
            if ( l_mag )  then
               e_mag_p_m(m)=fac_mag*rInt_R(e_mag_p_r_m_global(:,m),r,rscheme_oc)
               e_mag_t_m(m)=fac_mag*rInt_R(e_mag_t_r_m_global(:,m),r,rscheme_oc)
               e_mag_cmb_m(m)=fac_mag*e_mag_cmb_m(m)
            end if
            if ( l_anel ) then
               u2_p_m(m)   =fac_kin*rInt_R(u2_p_r_m_global(:,m),r,rscheme_oc)
               u2_t_m(m)   =fac_kin*rInt_R(u2_t_r_m_global(:,m),r,rscheme_oc)
            end if
            e_kin_p_m(m)   =fac_kin*rInt_R(e_kin_p_r_m_global(:,m),r,rscheme_oc)
            e_kin_t_m(m)   =fac_kin*rInt_R(e_kin_t_r_m_global(:,m),r,rscheme_oc)
            e_kin_nearSurf_m(m)=fac_kin*e_kin_nearSurf_m(m)
         end do
      end if
    
      !-- inner core:
    
      if ( l_cond_ic ) then
    
         O_r_icb_E_2=one/(r_ic(1)*r_ic(1))
         do n_r=1,n_r_ic_max
            r_ratio=r_ic(n_r)/r_ic(1)
            do mc=1,l_max+1
               e_mag_p_ic_r_m(n_r,mc)=0.0_cp
               e_mag_t_ic_r_m(n_r,mc)=0.0_cp
            end do
            do l=1,l_max
               e_mag_p_ic_r_l(n_r,l)=0.0_cp
               e_mag_t_ic_r_l(n_r,l)=0.0_cp
            end do
            !do lm=2,lm_max
            do lm=max(llm,2),ulm
               l =lo_map%lm2l(lm)
               m =lo_map%lm2m(lm)
               mc=m+1
               r_dr_b=r_ic(n_r)*db_ic(lm,n_r)
    
               e_mag_p_temp=dLh(map_glbl_st%lm2(l,m))*O_r_icb_E_2*r_ratio**(2*l) * ( &
               &            real((2*l+1)*(l+1),cp)*cc2real(b_ic(lm,n_r),m)   +  &
               &            real(2*(l+1),cp)*cc22real(b_ic(lm,n_r),r_dr_b,m) +  &
               &            cc2real(r_dr_b,m) )
               e_mag_t_temp=dLh(map_glbl_st%lm2(l,m))*r_ratio**(2*l+2) * &
               &            cc2real(aj_ic(lm,n_r),m)
    
               e_mag_p_ic_r_l(n_r,l)=e_mag_p_ic_r_l(n_r,l) + e_mag_p_temp
               e_mag_t_ic_r_l(n_r,l)=e_mag_t_ic_r_l(n_r,l) + e_mag_t_temp
               e_mag_p_ic_r_m(n_r,mc)=e_mag_p_ic_r_m(n_r,mc) + e_mag_p_temp
               e_mag_t_ic_r_m(n_r,mc)=e_mag_t_ic_r_m(n_r,mc) + e_mag_t_temp
            end do  ! loop over lm's
         end do ! loop over radial levels
    
#ifdef WITH_MPI
         call MPI_Reduce(e_mag_p_ic_r_l, e_mag_p_ic_r_l_global, n_r_ic_max*l_max,&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
         call MPI_Reduce(e_mag_t_ic_r_l, e_mag_t_ic_r_l_global, n_r_ic_max*l_max,&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
         call MPI_Reduce(e_mag_p_ic_r_m,e_mag_p_ic_r_m_global,n_r_ic_max*(l_max+1),&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
         call MPI_Reduce(e_mag_t_ic_r_m,e_mag_t_ic_r_m_global,n_r_ic_max*(l_max+1),&
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
#else
         e_mag_p_ic_r_l_global(:,:)=e_mag_p_ic_r_l(:,:)
         e_mag_t_ic_r_l_global(:,:)=e_mag_t_ic_r_l(:,:)
         e_mag_p_ic_r_m_global(:,:)=e_mag_p_ic_r_m(:,:)
         e_mag_t_ic_r_m_global(:,:)=e_mag_t_ic_r_m(:,:)
#endif
    
    
         if ( coord_r == 0 ) then
            !----- Radial Integrals:
            fac_mag=LFfac*half*eScale
            do l=1,l_max
               e_mag_p_ic_l(l)=fac_mag*rIntIC(e_mag_p_ic_r_l_global(1,l),    &
               &                              n_r_ic_max,dr_fac_ic,chebt_ic)
               e_mag_t_ic_l(l)=fac_mag*rIntIC(e_mag_t_ic_r_l_global(1,l),    &
               &                              n_r_ic_max,dr_fac_ic,chebt_ic)
            end do
            do m=1,l_max+1
               e_mag_p_ic_m(m)=fac_mag*rIntIC(e_mag_p_ic_r_m_global(1,m),    &
               &                              n_r_ic_max,dr_fac_ic,chebt_ic)
               e_mag_t_ic_m(m)=fac_mag*rIntIC(e_mag_t_ic_r_m_global(1,m),    &
               &                              n_r_ic_max,dr_fac_ic,chebt_ic)
            end do
         end if
      else
         do l=1,l_max
            e_mag_p_ic_l(l)=0.0_cp
            e_mag_t_ic_l(l)=0.0_cp
         end do
         do mc=1,l_max+1
            e_mag_p_ic_m(mc)=0.0_cp
            e_mag_t_ic_m(mc)=0.0_cp
         end do
      end if  ! conducting inner core ?
    
      if ( rank == 0 ) then
         !-- Output into files:
         if ( l_mag ) then
            write(string, *) n_spec
            mag_spec_file='mag_spec_'//trim(adjustl(string))//'.'//tag
            open(newunit=n_mag_spec_file, file=mag_spec_file, status='unknown')
            if ( n_spec == 0 ) then
               write(n_mag_spec_file,'(1x, &
               &           ''Magnetic energy spectra of time averaged field:'')')
            else
               write(n_mag_spec_file,'(1x, &
               &           ''Magnetic energy spectra at time:'', &
               &           ES20.12)') time*tScale
            end if
            write(n_mag_spec_file,'(1p,i4,11ES16.8)')            &
            &     0,0.0_cp,e_mag_p_m(1)   ,0.0_cp,e_mag_t_m(1),  &
            &     0.0_cp,e_mag_p_ic_m(1),0.0_cp,e_mag_t_ic_m(1), &
            &     0.0_cp,e_mag_cmb_m(1),0.0_cp
            do ml=1,l_max
               write(n_mag_spec_file,'(1p,i4,11ES16.8)')  &
               &     ml,e_mag_p_l(ml),   e_mag_p_m(ml+1), &
               &     e_mag_t_l(ml),   e_mag_t_m(ml+1),    &
               &     e_mag_p_ic_l(ml),e_mag_p_ic_m(ml+1), &
               &     e_mag_t_ic_l(ml),e_mag_t_ic_m(ml+1), &
               &     e_mag_cmb_l(ml), e_mag_cmb_m(ml+1),  &
               &     eCMB_global(ml)
            end do
            close(n_mag_spec_file)
    
            mag_spec_file='2D_mag_spec_'//trim(adjustl(string))//'.'//tag
            open(newunit=n_mag_spec_file, file=mag_spec_file, status='unknown', &
            &    form='unformatted')
    
            write(n_mag_spec_file) time*tScale,n_r_max,l_max,minc
            write(n_mag_spec_file) r
            write(n_mag_spec_file) fac_mag*e_mag_p_r_l_global
            write(n_mag_spec_file) fac_mag*e_mag_p_r_m_global
            write(n_mag_spec_file) fac_mag*e_mag_t_r_l_global
            write(n_mag_spec_file) fac_mag*e_mag_t_r_m_global
    
            close(n_mag_spec_file)
         end if
    
         if ( l_anel ) then
            write(string, *) n_spec
            u2_spec_file='u2_spec_'//trim(adjustl(string))//'.'//tag
            open(newunit=n_u2_spec_file, file=u2_spec_file, status='unknown')
            if ( n_spec == 0 ) then
               write(n_u2_spec_file,'(1x, &
               &          ''Velocity square spectra of time averaged field:'')')
            else
               write(n_u2_spec_file,'(1x,                       &
               &          ''Velocity square spectra at time:'', &
               &          ES20.12)') time*tScale
            end if
            write(n_u2_spec_file,'(1p,i4,4ES16.8)') &
            &        0,0.0_cp,u2_p_m(1),0.0_cp,u2_t_m(1)
            do ml=1,l_max
               write(n_u2_spec_file,'(1p,i4,4ES16.8)') &
               &     ml,u2_p_l(ml),u2_p_m(ml+1),u2_t_l(ml),u2_t_m(ml+1)
            end do
            close(n_u2_spec_file)
    
            u2_spec_file='2D_u2_spec_'//trim(adjustl(string))//'.'//tag
            open(newunit=n_u2_spec_file, file=u2_spec_file, status='unknown', &
            &    form='unformatted')
    
            write(n_u2_spec_file) time*tScale,n_r_max,l_max,minc
            write(n_u2_spec_file) r
            write(n_u2_spec_file) fac_kin*u2_p_r_l_global
            write(n_u2_spec_file) fac_kin*u2_p_r_m_global
            write(n_u2_spec_file) fac_kin*u2_t_r_l_global
            write(n_u2_spec_file) fac_kin*u2_t_r_m_global
    
            close(n_u2_spec_file)
    
         end if
    
         write(string, *) n_spec
         kin_spec_file='kin_spec_'//trim(adjustl(string))//'.'//tag
         open(newunit=n_kin_spec_file, file=kin_spec_file, status='unknown')
         if ( n_spec == 0 ) then
            write(n_kin_spec_file,'(1x, &
            &           ''Kinetic energy spectra of time averaged field:'')')
         else
            write(n_kin_spec_file,'(1x,                      &
            &           ''Kinetic energy spectra at time:'', &
            &           ES20.12)') time*tScale
         end if
         write(n_kin_spec_file,'(1p,i4,6ES16.8)')            &
         &     0,0.0_cp,e_kin_p_m(1),0.0_cp,e_kin_t_m(1),    &
         &     0.0_cp, e_kin_nearSurf_m(1)
         do ml=1,l_max
            write(n_kin_spec_file,'(1p,i4,6ES16.8)')    &
            &     ml,e_kin_p_l(ml),e_kin_p_m(ml+1),     &
            &     e_kin_t_l(ml),e_kin_t_m(ml+1),        &
            &     e_kin_nearSurf_l(ml), e_kin_nearSurf_m(ml+1)
         end do
         close(n_kin_spec_file)
    
         kin_spec_file='2D_kin_spec_'//trim(adjustl(string))//'.'//tag
         open(newunit=n_kin_spec_file, file=kin_spec_file, status='unknown', &
         &    form='unformatted')
    
         write(n_kin_spec_file) time*tScale,n_r_max,l_max,minc
         write(n_kin_spec_file) r
         write(n_kin_spec_file) fac_kin*e_kin_p_r_l_global
         write(n_kin_spec_file) fac_kin*e_kin_p_r_m_global
         write(n_kin_spec_file) fac_kin*e_kin_t_r_l_global
         write(n_kin_spec_file) fac_kin*e_kin_t_r_m_global
    
         close(n_kin_spec_file)
    
      end if
    
   end subroutine spectrum
!----------------------------------------------------------------------------
   subroutine spectrum_temp(n_spec,time,l_avg,n_time_ave,l_stop_time,       &
              &             time_passed,time_norm,s,ds)

      !-- Direct input:
      real(cp),     intent(in) :: time
      integer,     intent(in) :: n_time_ave
      integer,     intent(in) :: n_spec
      logical,     intent(in) :: l_stop_time
      real(cp),    intent(in) :: time_passed
      real(cp),    intent(in) :: time_norm
      complex(cp), intent(in) :: s(llm:ulm,n_r_max)
      complex(cp), intent(in) :: ds(llm:ulm,n_r_max)
      logical,     intent(in) :: l_avg

      !-- Local:
      character(len=14) :: string
      character(len=72) :: spec_file
      integer :: n_r,lm,l,m,lc,mc
      real(cp) :: T_temp
      real(cp) :: dT_temp
      real(cp) :: surf_ICB
      real(cp) :: fac,facICB

      real(cp) :: T_r_l(n_r_max,l_max+1),T_r_l_global(n_r_max,l_max+1)
      real(cp) :: T_r_m(n_r_max,l_max+1),T_r_m_global(n_r_max,l_max+1)
      real(cp) :: T_l(l_max+1), T_m(l_max+1)
      real(cp) :: T_ICB_l(l_max+1), T_ICB_l_global(l_max+1)
      real(cp) :: dT_ICB_l(l_max+1), dT_ICB_l_global(l_max+1)
      real(cp) :: T_ICB_m(l_max+1), T_ICB_m_global(l_max+1)
      real(cp) :: dT_ICB_m(l_max+1), dT_ICB_m_global(l_max+1)

      integer :: nOut,ierr

      T_l(:)     =0.0_cp
      T_ICB_l(:) =0.0_cp
      dT_ICB_l(:)=0.0_cp
      T_m(:)     =0.0_cp
      T_ICB_m(:) =0.0_cp
      dT_ICB_m(:)=0.0_cp

      do n_r=1,n_r_max
         do l=1,l_max+1
            T_r_l(n_r,l)=0.0_cp
            T_ICB_l(l)  =0.0_cp
            dT_ICB_l(l) =0.0_cp
            T_r_m(n_r,l)=0.0_cp
            T_ICB_m(l)  =0.0_cp
            dT_ICB_m(l) =0.0_cp
         end do
         do lm=llm,ulm
            l =lo_map%lm2l(lm)
            m =lo_map%lm2m(lm)
            lc=l+1
            mc=m+1

            T_temp =sqrt(cc2real(s(lm,n_r),m))/or2(n_r)
            dT_temp=sqrt(cc2real(ds(lm,n_r),m))/or2(n_r)

            !----- l-spectra:
            T_r_l(n_r,lc)=T_r_l(n_r,lc) + T_temp
            !----- m-spectra:
            T_r_m(n_r,mc)=T_r_m(n_r,mc) + T_temp

            !----- ICB spectra:
            if ( n_r == n_r_icb ) then
               T_ICB_l(lc) =T_ICB_l(lc) +T_temp
               T_ICB_m(mc) =T_ICB_m(mc) +T_temp
               dT_ICB_l(lc)=dT_ICB_l(lc)+dT_temp
               dT_ICB_m(mc)=dT_ICB_m(mc)+dT_temp
            end if

         end do    ! do loop over lms in block 
      end do    ! radial grid points 

      ! Reduction over all ranks
#ifdef WITH_MPI
      call MPI_Reduce(T_r_l,T_r_l_global,n_r_max*(l_max+1),      &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(T_r_m,T_r_m_global,n_r_max*(l_max+1),      &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(T_ICB_l,T_ICB_l_global,l_max+1,            &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(T_ICB_m,T_ICB_m_global,l_max+1,            &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(dT_ICB_l,dT_ICB_l_global,l_max+1,          &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(dT_ICB_m,dT_ICB_m_global,l_max+1,          &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
#else
      T_r_l_global(:,:) =T_r_l(:,:)
      T_r_m_global(:,:) =T_r_m(:,:)
      T_ICB_l_global(:) =T_ICB_l(:)
      T_ICB_m_global(:) =T_ICB_m(:)
      dT_ICB_l_global(:)=dT_ICB_l(:)
      dT_ICB_m_global(:)=dT_ICB_m(:)
#endif

      if ( coord_r == 0 .and. l_heat ) then
         !-- Radial Integrals:
         surf_ICB=four*pi*r_icb*r_icb
         fac      =one/vol_oc
         facICB   =one/surf_ICB
         do l=1,l_max+1
            T_l(l)=fac*rInt_R(T_r_l_global(:,l),r,rscheme_oc)
            T_ICB_l(l)=facICB*T_ICB_l_global(l)
            dT_ICB_l(l)=facICB*dT_ICB_l_global(l)
         end do
         do m=1,l_max+1 ! Note: counter m is actual order+1
            T_m(m)=fac*rInt_R(T_r_m_global(:,m),r,rscheme_oc)
            T_ICB_m(m)=facICB*T_ICB_m_global(m)
            dT_ICB_m(m)=facICB*dT_ICB_m_global(m)
         end do

         if ( l_avg ) then
            !-- Averaging:
            call get_mean_sd(T_l_ave, T_l_SD, T_l, n_time_ave, time_passed, time_norm)
            call get_mean_sd(T_ICB_l_ave, T_ICB_l_SD, T_ICB_l, n_time_ave, &
                 &           time_passed, time_norm)
            call get_mean_sd(dT_ICB_l_ave, dT_ICB_l_SD, dT_ICB_l, n_time_ave, &
                 &           time_passed, time_norm)
            call get_mean_sd(T_m_ave, T_m_SD, T_l, n_time_ave, time_passed, time_norm)
            call get_mean_sd(T_ICB_m_ave, T_ICB_m_SD, T_ICB_l, n_time_ave, &
                 &           time_passed, time_norm)
            call get_mean_sd(dT_ICB_m_ave, dT_ICB_m_SD, dT_ICB_l, n_time_ave, &
                 &           time_passed, time_norm)

            !-- Output:
            if ( l_stop_time ) then

               T_l_SD(:)     =sqrt(T_l_SD(:)/time_norm)
               T_ICB_l_SD(:) =sqrt(T_ICB_l_SD(:)/time_norm)
               dT_ICB_l_SD(:)=sqrt(dT_ICB_l_SD(:)/time_norm)
               T_m_SD(:)     =sqrt(T_m_SD(:)/time_norm)
               T_ICB_m_SD(:) =sqrt(T_ICB_m_SD(:)/time_norm)
               dT_ICB_m_SD(:)=sqrt(dT_ICB_m_SD(:)/time_norm)

               !------ Output:
               spec_file='T_spec_ave.'//tag
               open(newunit=nOut,file=spec_file,status='unknown')
               do l=1,l_max+1
                  write(nOut,'(2X,1P,I4,12ES16.8)') l-1, T_l_ave(l), T_m_ave(l),  &
                  &                              T_ICB_l_ave(l), T_ICB_m_ave(l),  &
                  &                            dT_ICB_l_ave(l), dT_ICB_m_ave(l),  &
                  &                                        T_l_SD(l), T_m_SD(l),  &
                  &                                T_ICB_l_SD(l), T_ICB_m_SD(l),  &
                  &                              dT_ICB_l_SD(l), dT_ICB_m_SD(l)
               end do
               close(nOut)

               if ( l_save_out ) then
                  open(newunit=n_log_file, file=log_file, status='unknown', &
                  &    position='append')
               end if
               write(n_log_file,"(/,A,A)")  &
               &    ' ! TIME AVERAGED T/C SPECTRA STORED IN FILE: ', spec_file
               write(n_log_file,"(A,I5)")  &
               &    ' !              No. of averaged spectra: ', n_time_ave
               if ( l_save_out ) close(n_log_file)

            end if

         else ! Just one spectrum

            !-- Output into files:
            write(string, *) n_spec
            spec_file='T_spec_'//trim(adjustl(string))//'.'//tag
            open(newunit=n_temp_spec_file, file=spec_file, status='unknown')
            write(n_temp_spec_file,'(1x,''TC spectra at time:'', ES20.12)')  &
            &     time*tScale
            do l=0,l_max
               write(n_temp_spec_file,'(1P,I4,6ES12.4)') l, T_l(l+1), T_m(l+1),   &
               &                                    T_ICB_l(l+1), T_ICB_m(l+1),   &
               &                                  dT_ICB_l(l+1), dT_ICB_m(l+1)
            end do
            close(n_temp_spec_file)

         end if

      end if

   end subroutine spectrum_temp
!----------------------------------------------------------------------------
   subroutine get_amplitude(time,w,dw,z,b,db,aj)

      !-- Input of variables:
      real(cp),    intent(in) :: time
      complex(cp), intent(in) :: w(llm:ulm,n_r_max)
      complex(cp), intent(in) :: dw(llm:ulm,n_r_max)
      complex(cp), intent(in) :: z(llm:ulm,n_r_max)
      complex(cp), intent(in) :: b(llmMag:ulmMag,n_r_maxMag)
      complex(cp), intent(in) :: db(llmMag:ulmMag,n_r_maxMag)
      complex(cp), intent(in) :: aj(llmMag:ulmMag,n_r_maxMag)

      !-- Output: 
      real(cp) :: e_mag_p_m(0:l_max),e_mag_t_m(0:l_max)
      real(cp) :: e_kin_p_m(0:l_max),e_kin_t_m(0:l_max)

      !-- Local variables:
      integer :: n_r,lm,l,m

      real(cp) :: e_mag_p_temp,e_mag_t_temp
      real(cp) :: e_kin_p_temp,e_kin_t_temp
      real(cp) :: fac_mag,fac_kin

      real(cp) :: e_mag_p_r_m(n_r_max,0:l_max),e_mag_p_r_m_global(n_r_max,0:l_max)
      real(cp) :: e_mag_t_r_m(n_r_max,0:l_max),e_mag_t_r_m_global(n_r_max,0:l_max)
      real(cp) :: e_kin_p_r_m(n_r_max,0:l_max),e_kin_p_r_m_global(n_r_max,0:l_max)
      real(cp) :: e_kin_t_r_m(n_r_max,0:l_max),e_kin_t_r_m_global(n_r_max,0:l_max)

      do n_r=1,n_r_max

         do m=0,l_max
            if ( l_mag ) then
               e_mag_p_r_m(n_r,m)=0.0_cp
               e_mag_t_r_m(n_r,m)=0.0_cp
            end if
            e_kin_p_r_m(n_r,m)=0.0_cp
            e_kin_t_r_m(n_r,m)=0.0_cp
         end do

         do lm=max(llm,2),ulm

            l  =lo_map%lm2l(lm)
            m  =lo_map%lm2m(lm)

            if ( l_mag ) then
               e_mag_p_temp=dLh(map_glbl_st%lm2(l,m)) * ( dLh(map_glbl_st%lm2(l,m))*    &
               &            or2(n_r)*cc2real(b(lm,n_r),m) + cc2real(db(lm,n_r),m) )
               e_mag_t_temp=dLh(map_glbl_st%lm2(l,m))*cc2real(aj(lm,n_r),m)     
            end if

            e_kin_p_temp=orho1(n_r)*dLh(map_glbl_st%lm2(l,m)) *  (                 &
            &            dLh(map_glbl_st%lm2(l,m))*or2(n_r)*cc2real(w(lm,n_r),m) + &
            &            cc2real(dw(lm,n_r),m) )
            e_kin_t_temp=orho1(n_r)*dLh(map_glbl_st%lm2(l,m))*cc2real(z(lm,n_r),m)

            !----- m-spectra:
            if ( l_mag ) then
               e_mag_p_r_m(n_r,m)=e_mag_p_r_m(n_r,m)+e_mag_p_temp
               e_mag_t_r_m(n_r,m)=e_mag_t_r_m(n_r,m)+e_mag_t_temp
            end if
            e_kin_p_r_m(n_r,m)=e_kin_p_r_m(n_r,m)+e_kin_p_temp                 
            e_kin_t_r_m(n_r,m)=e_kin_t_r_m(n_r,m)+e_kin_t_temp      

         end do    ! do loop over lms in block 

      end do    ! radial grid points 

#ifdef WITH_MPI
      if ( l_mag ) then
         call MPI_Reduce(e_mag_p_r_m, e_mag_p_r_m_global, n_r_max*(l_max+1), &
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
         call MPI_Reduce(e_mag_t_r_m, e_mag_t_r_m_global, n_r_max*(l_max+1), &
              &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      end if

      call MPI_Reduce(e_kin_p_r_m, e_kin_p_r_m_global, n_r_max*(l_max+1), &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
      call MPI_Reduce(e_kin_t_r_m, e_kin_t_r_m_global, n_r_max*(l_max+1), &
           &          MPI_DEF_REAL,MPI_SUM,0,comm_r,ierr)
#else
      e_mag_p_r_m_global(:,:)=e_mag_p_r_m(:,:)
      e_mag_t_r_m_global(:,:)=e_mag_t_r_m(:,:)
      e_kin_p_r_m_global(:,:)=e_kin_p_r_m(:,:)
      e_kin_t_r_m_global(:,:)=e_kin_t_r_m(:,:)
#endif

      if ( coord_r == 0 ) then

         !-- Radial Integrals:
         fac_mag=0.5*LFfac*eScale
         fac_kin=0.5*eScale
         do m=0,l_max ! Note: counter m is actual order+1
            if ( l_mag ) then
               e_mag_p_m(m)= fac_mag*rInt_R(e_mag_p_r_m_global(:,m),r,rscheme_oc)
               e_mag_t_m(m)= fac_mag*rInt_R(e_mag_t_r_m_global(:,m),r,rscheme_oc)
            end if
            e_kin_p_m(m)   =fac_kin*rInt_R(e_kin_p_r_m_global(:,m),r,rscheme_oc)       
            e_kin_t_m(m)   =fac_kin*rInt_R(e_kin_t_r_m_global(:,m),r,rscheme_oc)
         end do

         !-- Output
         if ( l_save_out ) then
            open(newunit=n_am_kpol_file,file=am_kpol_file,status='unknown', &
            &    form='unformatted',position='append')
         end if

         if (rank == 0) write(n_am_kpol_file) time,(e_kin_p_m(m),m=0,m_max_modes)

         if ( l_save_out ) then
            close(n_am_kpol_file)
         end if

         if ( l_save_out ) then
            open(newunit=n_am_ktor_file,file=am_ktor_file,status='unknown', &
            &    form='unformatted',position='append')
         end if

         if (rank == 0) write(n_am_ktor_file) time,(e_kin_t_m(m),m=0,m_max_modes)

         if ( l_save_out ) then
            close(n_am_ktor_file)
         end if

         if ( l_mag ) then
            if ( l_save_out ) then
               open(newunit=n_am_mpol_file,file=am_mpol_file,status='unknown', &
               &    form='unformatted',position='append')
            end if

            if (rank == 0) write(n_am_mpol_file) time,(e_mag_p_m(m),m=0,m_max_modes)

            if ( l_save_out ) then
               close(n_am_mpol_file)
            end if

            if ( l_save_out ) then
               open(newunit=n_am_mtor_file,file=am_mtor_file,status='unknown', &
               &    form='unformatted',position='append')
            end if

            if (rank == 0) write(n_am_mtor_file) time,(e_mag_t_m(m),m=0,m_max_modes)

            if ( l_save_out ) then
               close(n_am_mtor_file)
            end if
         end if

      end if ! coord_r == 0
    
   end subroutine get_amplitude 
!------------------------------------------------------------------------------
end module spectra

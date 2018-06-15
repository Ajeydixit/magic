module radial_spectra

   use precision_mod
   use parallel_mod
   use geometry, only: lm_max, n_r_max, n_r_ic_max, l_max, n_r_tot, n_r_icb
   use LMLoop_data, only: llm,ulm
   use radial_functions, only: or2, r_icb, r_ic
   use num_param, only: eScale
   use horizontal_data, only: dLh
   use logic, only: l_cond_ic
   use output_data, only: tag
   use useful, only: cc2real
   use LMmapping, only: radial_map, mappings
   use constants, only: pi, one, four, half

   implicit none

   private

   integer :: fileHandle

   public :: rBrSpec, rBpSpec

contains

   subroutine rBrSpec(time,Pol,PolIC,fileRoot,lIC,map)

      !-- Input variables
      real(cp),         intent(in) :: time
      complex(cp),      intent(in) :: Pol(llm:ulm,n_r_max)
      complex(cp),      intent(in) :: PolIC(llm:ulm,n_r_ic_max)
      character(len=*), intent(in) :: fileRoot
      logical,          intent(in) :: lIC
      type(mappings),   intent(in) :: map
    
      !-- Output to file:
      real(cp) :: e_p_AS(6,n_r_tot), e_p_AS_global(6,n_r_tot)
      real(cp) :: e_p(6,n_r_tot), e_p_global(6,n_r_tot)
    
      !-- Local:
      character(len=72) :: specFile
      integer :: n_r_loc,lm,l,m
      real(cp) :: fac,O_r_icb_E_2,rRatio,amp
      real(cp) :: e_p_temp
      logical :: lAS
    

      fac=half*eScale/(four*pi)
    
      do n_r_loc=1,n_r_max
         ! setting zero
         e_p(1:6,n_r_loc)   =0.0_cp
         e_p_AS(1:6,n_r_loc)=0.0_cp
    
         do lm=max(2,llm),ulm
            l=map%lm2l(lm)
            if ( l <= 6 ) then
               m=map%lm2m(lm)
               amp=real(Pol(lm,n_r_loc))
               e_p_temp=dLh(radial_map%lm2(l,m))**2 *or2(n_r_loc)*cc2real(Pol(lm,n_r_loc),m)
               if ( m == 0 ) then
                  if ( abs(amp)/=0.0_cp ) then
                     e_p_AS(l,n_r_loc)=fac*amp/abs(amp)*e_p_temp
                  end if
               end if
               e_p(l,n_r_loc)=e_p(l,n_r_loc)+fac*e_p_temp
            end if
         end do    ! do loop over lms in block
      end do    ! radial grid points
      
      !-- Inner core:
      if ( lIC ) then
    
         lAS=.true.
         if ( trim(adjustl(fileRoot)) == 'rBrAdvSpec' ) lAS= .false. 
    
         O_r_icb_E_2=one/r_icb**2
    
         do n_r_loc=2,n_r_ic_max
            rRatio=r_ic(n_r_loc)/r_ic(1)
            do l=1,6
               e_p(l,n_r_max-1+n_r_loc)=0.0_cp
               e_p_AS(l,n_r_max-1+n_r_loc)=0.0_cp
            end do
            do lm=max(2,llm),ulm
               l=map%lm2l(lm)
               if ( l <= 6 ) then
                  m=map%lm2m(lm)
                  if ( m /= 0 .or. lAS ) then
                     if ( l_cond_ic ) then
                        e_p_temp=dLh(radial_map%lm2(l,m))*rRatio**(2*l) * &
                        &        dLh(radial_map%lm2(l,m))*O_r_icb_E_2*    &
                        &        cc2real(PolIC(lm,n_r_loc),m)
                        amp=real(PolIC(lm,n_r_loc))
                     else
                        e_p_temp=dLh(radial_map%lm2(l,m))*O_r_icb_E_2*rRatio**(2*l) * &
                        &        dLh(radial_map%lm2(l,m))*cc2real(PolIC(lm,n_r_ICB),m)
                        amp=real(Pol(lm,n_r_ICB))
                     end if
                     if ( m == 0 ) then
                        if ( abs(amp) /= 0.0_cp) then
                           e_p_AS(l,n_r_max-1+n_r_loc)= fac*amp/abs(amp)*e_p_temp
                        end if
                     end if
                     e_p(l,n_r_max-1+n_r_loc)=e_p(l,n_r_max-1+n_r_loc) + fac*e_p_temp
                  end if
               end if
            end do
         end do
      else
         do n_r_loc=2,n_r_ic_max
            do l=1,6
               e_p_AS(l,n_r_max-1+n_r_loc)=0.0_cp
               e_p(l,n_r_max-1+n_r_loc)   =0.0_cp
            end do
         end do
      end if

#ifdef WITH_MPI
      call MPI_Reduce(e_p,e_p_global, 6*n_r_tot, MPI_DEF_REAL, &
           &          MPI_SUM, 0, comm_r, ierr )
      call MPI_Reduce(e_p_AS,e_p_AS_global, 6*n_r_tot, MPI_DEF_REAL, &
           &          MPI_SUM, 0, comm_r, ierr )
#else
      e_p_global(:,:)   =e_p(:,:)
      e_p_AS_global(:,:)=e_p_AS(:,:)
#endif
      
      if ( rank == 0 ) then

         !-- Output into file:
         !     writing l=0/1/2 magnetic energy
         specFile=trim(adjustl(fileRoot))//'.'//tag
         open(newunit=fileHandle, file=specFile, form='unformatted', &
         &    status='unknown', position='append')
       
         write(fileHandle) real(time,kind=outp),                                &
         &                (real(e_p_global(1,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),  &
         &                (real(e_p_global(2,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),  &
         &                (real(e_p_global(3,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),  &
         &                (real(e_p_global(4,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),  &
         &                (real(e_p_global(5,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),  &
         &                (real(e_p_global(6,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1)
         write(fileHandle) real(time,kind=outp),                                  &
         &                (real(e_p_AS_global(1,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_p_AS_global(2,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_p_AS_global(3,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_p_AS_global(4,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_p_AS_global(5,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_p_AS_global(6,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1)
       
         close(fileHandle)

      end if
    
   end subroutine rBrSpec
!----------------------------------------------------------------------------
   subroutine rBpSpec(time,Tor,TorIC,fileRoot,lIC,map)
      !
      !  Called from rank0, map gives the lm order of Tor and TorIC
      !

      !-- Input variables:
      real(cp),         intent(in) :: time
      complex(cp),      intent(in) :: Tor(llm:ulm,n_r_max)
      complex(cp),      intent(in) :: TorIC(llm:ulm,n_r_ic_max)
      character(len=*), intent(in) :: fileRoot
      logical,          intent(in) :: lIC
      type(mappings),   intent(in) :: map
    
      !-- Output:
      real(cp) :: e_t_AS(6,n_r_tot), e_t_AS_global(6,n_r_tot)
      real(cp) :: e_t(6,n_r_tot), e_t_global(6,n_r_tot)
    
      !-- Local:
      character(len=72) :: specFile
      integer :: n_r_loc,lm,l,m
      real(cp) :: fac,rRatio,amp
      real(cp) :: e_t_temp
      LOGICAl :: lAS
    
      fac=half*eScale/(four*pi)
    
      do n_r_loc=1,n_r_max
         do l=1,6
            e_t(l,n_r_loc)   =0.0_cp
            e_t_AS(l,n_r_loc)=0.0_cp
         end do
         do lm=max(2,llm),ulm
            l=map%lm2l(lm)
            if ( l <= 6 ) then
               m=map%lm2m(lm)
               amp=real(Tor(lm,n_r_loc))
               e_t_temp=dLh(radial_map%lm2(l,m))*cc2real(Tor(lm,n_r_loc),m)
               if ( abs(amp)/=0.0_cp ) then
                  if ( m == 0 ) e_t_AS(l,n_r_loc)=fac*amp/abs(amp)*e_t_temp
               end if
               e_t(l,n_r_loc)=e_t(l,n_r_loc)+fac*e_t_temp
            end if
         end do    ! do loop over lms in block
      end do    ! radial grid points
    
      !-- Inner core:
      do n_r_loc=2,n_r_ic_max
         do l=1,6
            e_t_AS(l,n_r_max-1+n_r_loc)=0.0_cp
            e_t(l,n_r_max-1+n_r_loc)   =0.0_cp
         end do
      end do
      if ( lIC .and. l_cond_ic ) then
    
         lAS=.true.
         if ( trim(adjustl(fileRoot)) == 'rBrAdvSpec' ) lAS= .false. 
    
         do n_r_loc=2,n_r_ic_max
            rRatio=r_ic(n_r_loc)/r_ic(1)
            do lm=max(2,llm),ulm
               l=map%lm2l(lm)
               if ( l <= 6 ) then
                  m=map%lm2m(lm)
                  if ( m /= 0 .or. lAS ) then
                     e_t_temp= dLh(radial_map%lm2(l,m))*rRatio**(2*l+2) &
                          &    * cc2real(TorIC(lm,n_r_loc),m)
                     amp=real(TorIC(lm,n_r_loc))
                     if ( abs(amp)/=0.0_cp ) then
                        if ( m == 0 ) e_t_AS(l,n_r_max-1+n_r_loc)= &
                             fac*amp/abs(amp)*e_t_temp
                     end if
                     e_t(l,n_r_max-1+n_r_loc)=e_t(l,n_r_max-1+n_r_loc)+fac*e_t_temp
                  end if
               end if
            end do
         end do
    
      end if

#ifdef WITH_MPI
      call MPI_Reduce(e_t,e_t_global, 6*n_r_tot, MPI_DEF_REAL, &
           &          MPI_SUM, 0, comm_r, ierr )
      call MPI_Reduce(e_t_AS,e_t_AS_global, 6*n_r_tot, MPI_DEF_REAL, &
           &          MPI_SUM, 0, comm_r, ierr )
#else
      e_t_global(:,:)   =e_t(:,:)
      e_t_AS_global(:,:)=e_t_AS(:,:)
#endif
      
      if ( rank == 0 ) then
    
         !-- Output into file:
         !     writing l=0/1/2 magnetic energy
         specFile=trim(adjustl(fileRoot))//'.'//tag
         open(newunit=fileHandle, file=specFile, form='unformatted', &
         &    status='unknown', position='append')
       
         write(fileHandle) real(time,kind=outp),                                  &
         &                (real(e_t_global(1,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),    &
         &                (real(e_t_global(2,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),    &
         &                (real(e_t_global(3,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),    &
         &                (real(e_t_global(4,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),    &
         &                (real(e_t_global(5,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1),    &
         &                (real(e_t_global(6,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1)
         write(fileHandle) real(time,kind=outp),                                  &
         &                (real(e_t_AS_global(1,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_t_AS_global(2,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_t_AS_global(3,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_t_AS_global(4,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_t_AS_global(5,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1), &
         &                (real(e_t_AS_global(6,n_r_loc),kind=outp),n_r_loc=1,n_r_tot-1)
       
         close(fileHandle)

      end if
    
   end subroutine rBpSpec
!----------------------------------------------------------------------------
end module radial_spectra

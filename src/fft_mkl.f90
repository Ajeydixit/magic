#include "perflib_preproc.cpp"
#include "mkl_dfti.f90"

module fft

   use precision_mod
   use constants, only: one
   use truncation, only: nrp, ncp, n_phi_max, n_theta_max, m_max
   use blocking, only: nfs
   !use parallel_mod, only: nThreads
   use mkl_dfti
 
   implicit none
   
   private
 
   !----------- MKL specific variables -------------
   integer :: status
   type(DFTI_DESCRIPTOR), pointer :: c2r_handle, r2c_handle
   type(DFTI_DESCRIPTOR), pointer :: phi2m_handle, m2phi_handle
   !----------- END MKL specific variables
 
   public :: fft_thetab, init_fft, fft_to_real, finalize_fft
#ifdef WITH_SHTNS
   public :: init_fft_phi, finalize_fft_phi, fft_phi, m2phi_handle, phi2m_handle
#endif

contains

   subroutine init_fft(number_of_points)
      !
      ! MKL equivalent of init_fft
      !

      !-- Input variable
      integer, intent(in) :: number_of_points ! number of points

      ! Fourier transformation complex->REAL with MKL DFTI interface
      ! init FFT
      status = DftiCreateDescriptor( c2r_handle, DFTI_DOUBLE, DFTI_REAL, &
                                     1, number_of_points )
      status = DftiSetValue( c2r_handle, DFTI_NUMBER_OF_TRANSFORMS, nfs )
      status = DftiSetValue( c2r_handle, DFTI_INPUT_DISTANCE, nrp )
      status = DftiSetValue( c2r_handle, DFTI_OUTPUT_DISTANCE, nrp )
      !status = DftiSetValue( c2r_handle, DFTI_CONJUGATE_EVEN_STORAGE, &
      !                       DFTI_COMPLEX_COMPLEX )
#ifdef WITH_SHTNS
      status = DftiSetValue( c2r_handle, DFTI_PLACEMENT, DFTI_NOT_INPLACE )
#else
      status = DftiSetValue( c2r_handle, DFTI_PLACEMENT, DFTI_INPLACE )
#endif
      ! This is supposed to fix the issue for ifort < 14 but it increases the
      ! walltime
      !status = DftiSetValue( c2r_handle, DFTI_NUMBER_OF_USER_THREADS, nThreads)
      status = DftiCommitDescriptor( c2r_handle )
  
      ! Fourier transformation REAL->complex with MKL DFTI interface
      ! init FFT
      status = DftiCreateDescriptor( r2c_handle, DFTI_DOUBLE, DFTI_REAL, &
                                     1, number_of_points )
      status = DftiSetValue( r2c_handle, DFTI_NUMBER_OF_TRANSFORMS, nfs )
      status = DftiSetValue( r2c_handle, DFTI_INPUT_DISTANCE, nrp )
      status = DftiSetValue( r2c_handle, DFTI_OUTPUT_DISTANCE, nrp )
      !status = DftiSetValue( r2c_handle, DFTI_CONJUGATE_EVEN_STORAGE, &
      !                       DFTI_COMPLEX_COMPLEX )
#ifdef WITH_SHTNS
      status = DftiSetValue( r2c_handle, DFTI_PLACEMENT, DFTI_NOT_INPLACE )
#else
      status = DftiSetValue( r2c_handle, DFTI_PLACEMENT, DFTI_INPLACE )
#endif
      status = DftiSetValue( r2c_handle, DFTI_FORWARD_SCALE, &
                             one/real(number_of_points,cp) )
      !status = DftiSetValue( r2c_handle, DFTI_NUMBER_OF_USER_THREADS, nThreads)
      status = DftiCommitDescriptor( r2c_handle )
      
   end subroutine init_fft
#ifdef WITH_SHTNS
!------------------------------------------------------------------------------
  subroutine init_fft_phi
!>@author Rafael Lago, MPCDF, July 2017
!------------------------------------------------------------------------------
    integer :: status
    
    status = DftiCreateDescriptor( phi2m_handle, DFTI_DOUBLE, DFTI_COMPLEX, 1, n_phi_max )
    status = DftiSetValue( phi2m_handle, DFTI_NUMBER_OF_TRANSFORMS, n_theta_max)
    status = DftiSetValue( phi2m_handle, DFTI_INPUT_DISTANCE, n_phi_max )
    status = DftiSetValue( phi2m_handle, DFTI_OUTPUT_DISTANCE, m_max )
    status = DftiSetValue( phi2m_handle, DFTI_PLACEMENT, DFTI_NOT_INPLACE )
    status = DftiSetValue( phi2m_handle, DFTI_FORWARD_SCALE, 1.0_cp/real(n_phi_max,cp) )
    status = DftiSetValue( phi2m_handle, DFTI_BACKWARD_SCALE, 1.0_cp/real(m_max,cp) )
    status = DftiCommitDescriptor( phi2m_handle )
    
  end subroutine

!------------------------------------------------------------------------------
  subroutine finalize_fft_phi
!>@author Rafael Lago, MPCDF, July 2017
!------------------------------------------------------------------------------
    integer :: status
    
    status = DftiFreeDescriptor(phi2m_handle)
    status = DftiFreeDescriptor(m2phi_handle)
  end subroutine
  
!------------------------------------------------------------------------------
  subroutine fft_phi(f, g, dir)
!>@author Rafael Lago, MPCDF, July 2017
!------------------------------------------------------------------------------
    complex(cp), intent(inout)  :: f(n_phi_max*n_theta_max)
    complex(cp), intent(inout)  :: g(m_max*n_theta_max)
    integer,     intent(in)     :: dir
    integer :: status
    
    if (dir == 1) then
      status  = DftiComputeForward(  phi2m_handle, f, g )
    else if (dir == -1) then
      status  = DftiComputeBackward( phi2m_handle, g, f )
    else
      print *, "Unknown direction in fft_phi: ", dir
    end if
    
  end subroutine
#endif
!------------------------------------------------------------------------------
   subroutine finalize_fft

      status = DftiFreeDescriptor( c2r_handle )
      status = DftiFreeDescriptor( r2c_handle )

   end subroutine finalize_fft
!------------------------------------------------------------------------------
   subroutine fft_thetab(f,dir)

      real(cp), intent(inout) :: f(nrp,nfs)
      integer,  intent(in) :: dir            ! back or forth transform

      PERFON('fft_thr')
      if (dir == -1) then
         ! run FFT
         status = DftiComputeForward( r2c_handle, f(:,1) )
      else if (dir == 1) then
         ! we want a backward transform, and the real array f 
         ! is to be interpreted as complex array

         ! run FFT
         status = DftiComputeBackward( c2r_handle, f(:,1) )

         !PRINT*,"Calling fft_thetab with real array and dir /= -1. & 
         !        Don't know what to do!"
         !call TRACEBACKQQ
      end if
      PERFOFF

   end subroutine fft_thetab
!------------------------------------------------------------------------------
   subroutine fft_to_real(f,ld_f,nrep)

      integer,  intent(in) :: ld_f,nrep
      real(cp), intent(inout) :: f(ld_f,nrep)

      type(DFTI_DESCRIPTOR), pointer :: local_c2r_handle
#ifdef WITH_SHTNS
      real(cp), allocatable :: work_array(:, :)
      allocate(work_array(ld_f+2, nrep))
#endif

      PERFON('fft2r')
      ! Fourier transformation complex->REAL with MKL DFTI interface
      ! init FFT
      status = DftiCreateDescriptor( local_c2r_handle, DFTI_DOUBLE, &
                                     DFTI_REAL, 1, n_phi_max )
      status = DftiSetValue( local_c2r_handle, DFTI_NUMBER_OF_TRANSFORMS, nrep )
      status = DftiSetValue( local_c2r_handle, DFTI_OUTPUT_DISTANCE, ld_f )
#ifdef WITH_SHTNS
      status = DftiSetValue( local_c2r_handle, DFTI_INPUT_DISTANCE, ld_f+2 )
      status = DftiSetValue( local_c2r_handle, DFTI_PLACEMENT, DFTI_NOT_INPLACE )
#else
      status = DftiSetValue( local_c2r_handle, DFTI_INPUT_DISTANCE, ld_f )
      status = DftiSetValue( local_c2r_handle, DFTI_PLACEMENT, DFTI_INPLACE )
#endif
      status = DftiCommitDescriptor( local_c2r_handle )

      ! run FFT
#ifdef WITH_SHTNS
      work_array(1:n_phi_max, :) = f(1:n_phi_max, :)
      work_array(n_phi_max+1:n_phi_max+2, :) = 0.0_cp
      status = DftiComputeBackward( local_c2r_handle, work_array(:, 1), f(:,1) )
      deallocate(work_array)
#else
      status = DftiComputeBackward( local_c2r_handle, f(:,1) )
#endif

      status = DftiFreeDescriptor( local_c2r_handle )
      PERFOFF

   end subroutine fft_to_real
!------------------------------------------------------------------------------
end module fft

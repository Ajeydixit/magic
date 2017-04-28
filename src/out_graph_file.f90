#include "perflib_preproc.cpp"
#define ONE_LARGE_BLOCK

module graphOut_mod
   !
   ! This module contains the subroutines that store the 3-D graphic files.
   !

   use parallel_mod
   use precision_mod
   use truncation, only: lm_maxMag, n_r_maxMag, n_r_ic_maxMag, lm_max, &
       &                 n_theta_max, n_phi_tot, n_r_max, l_max, minc, &
       &                 n_phi_max, nrp, n_r_ic_max, l_axi
   use radial_data, only: n_r_icb
   use radial_functions, only: r_cmb, orho1, or1, or2, r, r_icb, r_ic, &
       &                       O_r_ic, O_r_ic2
   use physical_parameters, only: ra, ek, pr, prmag, radratio, sigma_ratio
   use num_param, only: vScale
   use blocking, only: nThetaBs, sizeThetaB, nfs
   use horizontal_data, only: theta_ord, dLh, Plm, dPlm, O_sin_theta
   use logic, only: l_mag, l_cond_ic, l_PressGraph, l_chemical_conv
#ifdef WITH_MPI
   use output_data, only: n_graph_file, runid, graph_mpi_fh
#else
   use output_data, only: n_graph_file, runid
#endif
#ifdef WITH_SHTNS
   use shtns
#else
   use fft
#endif
   use legendre_spec_to_grid, only: legTF
   use leg_helper_mod, only: legPrep_IC

   implicit none

   private

#ifdef WITH_MPI
   public :: graphOut, graphOut_mpi, graphOut_IC, graphOut_mpi_header
#else
   public :: graphOut, graphOut_IC, graphOut_header
#endif

contains

   subroutine graphOut(time,n_r,vr,vt,vp,br,bt,bp,sr,prer,xir,      &
     &              n_theta_start,n_theta_block_size,lGraphHeader)
      !
      !
      !  Output of components of velocity, magnetic field vector and
      !  entropy for graphics.
      !
      !  * n_r: (input) for n_r = 0 a header is written.
      !    for n_r > 0 values at radial level n_r are written
      !
      !  * vr...sr: (input) arrays with grid-point values
      !
      !  * n_theta_start : (input) values are written for theta-points :
      !    ``n_theta_start <= n_theta <= n_theta_start-1+n_theta_block``
      !
    
      !-- Input variables
      real(cp), intent(in) :: time
      integer,  intent(in) :: n_r                    ! radial grod point no.
      integer,  intent(in) :: n_theta_start          ! start theta no.
      integer,  intent(in) :: n_theta_block_size     ! size of theta block
      real(cp), intent(in) :: vr(nrp,*),vt(nrp,*),vp(nrp,*)
      real(cp), intent(in) :: br(nrp,*),bt(nrp,*),bp(nrp,*)
      real(cp), intent(in) :: sr(nrp,*),prer(nrp,*),xir(nrp,*)

      logical,  intent(inout) :: lGraphHeader
    
      !-- Local variables:
      integer :: n_theta_stop  ! end theta no.
      integer :: n_phi         ! counter for longitude
      integer :: n_theta       ! counter for colatitude
      integer :: n_theta_cal   ! position of block colat in all colats
    
      real(cp) :: fac,fac_r
      real(outp) :: dummy(n_phi_max,nfs)
    
      character(len=20) :: version
      
      if ( rank /= 0 ) return
    
      !-- Write header & colatitudes for n_r=0:
      if ( l_chemical_conv ) then
         if ( l_PressGraph ) then
            version='Graphout_Version_6'
         else
            version='Graphout_Version_5'
         end if
      else
         if ( l_PressGraph ) then
            version='Graphout_Version_8'
         else
            version='Graphout_Version_7'
         end if
      end if
    
      if ( lGraphHeader ) then
    
         !-------- Write parameters:
         write(n_graph_file) version
         write(n_graph_file) runid
         write(n_graph_file) real(time,outp), real(n_r_max,outp),          &
                             real(n_theta_max,outp), real(n_phi_tot,outp), &
                             real(n_r_ic_max-1,outp), real(minc,outp),     &
                             real(nThetaBs,outp), real(ra,outp),           &
                             real(ek,outp), real(pr,outp),                 &
                             real(prmag,outp), real(radratio,outp),        &
                             real(sigma_ratio,outp)
 
         !-------- Write colatitudes:
         write(n_graph_file) (real(theta_ord(n_theta),outp), n_theta=1,n_theta_max)
    
         lGraphHeader=.false.
    
      else  ! Call not for writing header
    
         !*******************************************************************
         !  define CRITICAL section, so that the write statements do not
         !  get mixed up
         !*******************************************************************
    
         !-- Determine radius and thetas in this block:
         n_theta_stop=n_theta_start+n_theta_block_size-1
    
         write(n_graph_file) real(n_r-1,outp),real(r(n_r)/r(1),outp), &
                             real(n_theta_start,outp),real(n_theta_stop,outp)
    
         !-- Write entropy:
         do n_theta=1,n_theta_block_size,2
            do n_phi=1,n_phi_max ! do loop over phis
               dummy(n_phi,n_theta)  =real(sr(n_phi,n_theta),kind=outp)   ! NHS
               dummy(n_phi,n_theta+1)=real(sr(n_phi,n_theta+1),kind=outp) ! SHS
            end do
         end do
         call graph_write(n_phi_max,n_theta_block_size,dummy,n_graph_file)
    
         !-- Calculate and write radial velocity:
         fac=or2(n_r)*vScale*orho1(n_r)
         do n_theta=1,n_theta_block_size,2
            do n_phi=1,n_phi_max
               dummy(n_phi,n_theta)  =real(fac*vr(n_phi,n_theta),kind=outp)
               dummy(n_phi,n_theta+1)=real(fac*vr(n_phi,n_theta+1),kind=outp)
            end do
         end do
         call graph_write(n_phi_max,n_theta_block_size,dummy,n_graph_file)
    
    
         !-- Calculate and write latitudinal velocity:
         fac_r=or1(n_r)*vScale*orho1(n_r)
         do n_theta=1,n_theta_block_size,2
            n_theta_cal=n_theta_start+n_theta-1
            fac=fac_r*O_sin_theta(n_theta_cal)
            do n_phi=1,n_phi_max
               dummy(n_phi,n_theta)  =real(fac*vt(n_phi,n_theta),kind=outp)
               dummy(n_phi,n_theta+1)=real(fac*vt(n_phi,n_theta+1),kind=outp)
            end do
         end do
         call graph_write(n_phi_max,n_theta_block_size,dummy,n_graph_file)
    
         !-- Calculate and write longitudinal velocity:
         fac_r=or1(n_r)*vScale*orho1(n_r)
         do n_theta=1,n_theta_block_size,2
            n_theta_cal=n_theta_start+n_theta-1
            fac=fac_r*O_sin_theta(n_theta_cal)
            do n_phi=1,n_phi_max
               dummy(n_phi,n_theta)  =real(fac*vp(n_phi,n_theta),kind=outp)
               dummy(n_phi,n_theta+1)=real(fac*vp(n_phi,n_theta+1),kind=outp)
            end do
         end do
         call graph_write(n_phi_max,n_theta_block_size,dummy,n_graph_file)

         if ( version == 'Graphout_Version_5' .or. version == 'Graphout_Version_6') then
            !-- Write composition:
            do n_theta=1,n_theta_block_size,2
               do n_phi=1,n_phi_max ! do loop over phis
                  dummy(n_phi,n_theta)  =real(xir(n_phi,n_theta),kind=outp)   ! NHS
                  dummy(n_phi,n_theta+1)=real(xir(n_phi,n_theta+1),kind=outp) ! SHS
               end do
            end do
            call graph_write(n_phi_max,n_theta_block_size,dummy,n_graph_file)
         end if

         if ( version == 'Graphout_Version_6' .or. version == 'Graphout_Version_8') then
            !-- Write pressure:
            do n_theta=1,n_theta_block_size,2
               do n_phi=1,n_phi_max ! do loop over phis
                  dummy(n_phi,n_theta)  =real(prer(n_phi,n_theta),kind=outp)   ! NHS
                  dummy(n_phi,n_theta+1)=real(prer(n_phi,n_theta+1),kind=outp) ! SHS
               end do
            end do
            call graph_write(n_phi_max,n_theta_block_size,dummy,n_graph_file)
         end if
    
         if ( l_mag ) then
    
            !-- Calculate and write radial magnetic field:
            fac=or2(n_r)
            do n_theta=1,n_theta_block_size,2
               do n_phi=1,n_phi_max
                  dummy(n_phi,n_theta)  =real(fac*br(n_phi,n_theta),kind=outp)
                  dummy(n_phi,n_theta+1)=real(fac*br(n_phi,n_theta+1),kind=outp)
               end do
            end do
            call graph_write(n_phi_max,n_theta_block_size,dummy,n_graph_file)
    
            !-- Calculate and write latitudinal magnetic field:
            do n_theta=1,n_theta_block_size,2
               n_theta_cal=n_theta_start+n_theta-1
               fac=or1(n_r)*O_sin_theta(n_theta_cal)
               do n_phi=1,n_phi_max
                  dummy(n_phi,n_theta)  =real(fac*bt(n_phi,n_theta),kind=outp)
                  dummy(n_phi,n_theta+1)=real(fac*bt(n_phi,n_theta+1),kind=outp)
               end do
            end do
            call graph_write(n_phi_max,n_theta_block_size,dummy,n_graph_file)
    
            !-- Calculate and write longitudinal magnetic field:
            do n_theta=1,n_theta_block_size,2
               n_theta_cal=n_theta_start+n_theta-1
               fac=or1(n_r)*O_sin_theta(n_theta_cal)
               do n_phi=1,n_phi_max
                  dummy(n_phi,n_theta)  =real(fac*bp(n_phi,n_theta),kind=outp)
                  dummy(n_phi,n_theta+1)=real(fac*bp(n_phi,n_theta+1),kind=outp)
               end do
            end do
            call graph_write(n_phi_max,n_theta_block_size,dummy,n_graph_file)
    
         end if ! l_mag ?
    
         !-- End of CRITICAL section ********************************************
    
      end if

   end subroutine graphOut
!-----------------------------------------------------------------------
   subroutine graphOut_header(time)
    
      !-- Input variables
      real(cp), intent(in) :: time

      !-- Local variables:
      character(len=20) :: version
      integer :: n_theta
    
    
      !-- Write header & colatitudes for n_r=0:
      if ( l_chemical_conv ) then
         if ( l_PressGraph ) then
            version='Graphout_Version_6'
         else
            version='Graphout_Version_5'
         end if
      else
         if ( l_PressGraph ) then
            version='Graphout_Version_8'
         else
            version='Graphout_Version_7'
         end if
      end if

      !-------- Write parameters:
      write(n_graph_file) version
      write(n_graph_file) runid
      write(n_graph_file) real(time,outp), real(n_r_max,outp),          &
                          real(n_theta_max,outp), real(n_phi_tot,outp), &
                          real(n_r_ic_max-1,outp), real(minc,outp),     &
                          real(nThetaBs,outp), real(ra,outp),           &
                          real(ek,outp), real(pr,outp),                 &
                          real(prmag,outp), real(radratio,outp),        &
                          real(sigma_ratio,outp)

      !-------- Write colatitudes:
      write(n_graph_file) (real(theta_ord(n_theta),outp), n_theta=1,n_theta_max)
 
   end subroutine graphOut_header
!-------------------------------------------------------------------------------
#ifdef WITH_MPI
   subroutine graphOut_mpi(time,n_r,vr,vt,vp,br,bt,bp,sr,prer,xir, &
            &              n_theta_start,n_theta_block_size,lGraphHeader)
      !
      ! MPI version of the graphOut subroutine (use of MPI_IO)
      !

      !-- Input variables:
      real(cp), intent(in) :: time
      integer,  intent(in) :: n_r                      ! radial grod point no.
      integer,  intent(in) :: n_theta_start            ! start theta no.
      integer,  intent(in) :: n_theta_block_size       ! size of theta block
      real(cp), intent(in) :: vr(nrp,*),vt(nrp,*),vp(nrp,*)
      real(cp), intent(in) :: br(nrp,*),bt(nrp,*),bp(nrp,*)
      real(cp), intent(in) :: sr(nrp,*),prer(nrp,*),xir(nrp,*)

      logical, intent(inout) :: lGraphHeader

      !-- Local variables:
      integer :: n_phi         ! counter for longitude
      integer :: n_theta       ! counter for colatitude
      integer :: n_theta_cal   ! position of block colat in all colats
      integer :: n_theta_stop  ! end theta no.

      real(cp) :: fac,fac_r
      real(outp) :: dummy(n_phi_max,nfs)

      character(len=20) :: version

      ! MPI related variables
      !integer :: info
      integer :: status(MPI_STATUS_SIZE)
      !character(len=MPI_MAX_ERROR_STRING) :: error_string
      !integer :: count
      integer :: bytes_written!,length_of_error
      integer :: size_of_header, size_of_data_per_rank, size_of_data_per_r
      integer :: size_of_data_per_thetaB
      integer(kind=MPI_OFFSET_kind) :: disp
      integer :: etype,filetype
      character(len=MPI_MAX_DATAREP_STRING) :: datarep
      ! end of MPI related variables

      if ( l_chemical_conv ) then
         if ( l_PressGraph ) then
            version='Graphout_Version_12'
         else
            version='Graphout_Version_11'
         end if
      else
         if ( l_PressGraph ) then
            version='Graphout_Version_10'
         else
            version='Graphout_Version_9'
         end if
      end if

      !$OMP CRITICAL
      if ( lGraphHeader ) then
         size_of_header = 8+len(version)+8+len(runid)+8+ &
                          13*SIZEOF_INTEGER+8+n_theta_max*SIZEOF_OUT_REAL

#ifdef ONE_LARGE_BLOCK
         size_of_data_per_thetaB = 8+4*SIZEOF_OUT_REAL+3* &
                                   (8+n_phi_max*SIZEOF_OUT_REAL*n_theta_block_size)
         if ( version=='Graphout_Version_10' .or. version=='Graphout_Version_11') then
            size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                   (8+n_phi_max*SIZEOF_OUT_REAL*n_theta_block_size)
         else if ( version=='Graphout_Version_12') then
            size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                   2*(8+n_phi_max*SIZEOF_OUT_REAL*n_theta_block_size)
         end if

         if ( l_mag ) size_of_data_per_thetaB = size_of_data_per_thetaB + &
                            3*(8+n_phi_max*SIZEOF_OUT_REAL*n_theta_block_size)
#else
         size_of_data_per_thetaB = 8+4*SIZEOF_OUT_REAL+ &
                                   3*(8+n_phi_max*SIZEOF_OUT_REAL)*n_theta_block_size
         if ( version=='Graphout_Version_10' .or. version=='Graphout_Version_11') then
            size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                   (8+n_phi_max*SIZEOF_OUT_REAL)*n_theta_block_size
         else if ( version=='Graphout_Version_12') then
            size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                   2*(8+n_phi_max*SIZEOF_OUT_REAL)*n_theta_block_size
         end if

         if ( l_mag ) size_of_data_per_thetaB = size_of_data_per_thetaB + &
                            3*(8+n_phi_max*SIZEOF_OUT_REAL)*n_theta_block_size
#endif
         size_of_data_per_r = size_of_data_per_thetaB * nThetaBs
         size_of_data_per_rank = size_of_data_per_r * nR_per_rank

         if ( coord_r == 0 ) then
            ! coord_r zero writes the Header
            disp = 0
            call MPI_FILE_SET_VIEW(graph_mpi_fh,disp,MPI_CHARACTER, &
                                   MPI_CHARACTER,"external32",MPI_INFO_NULL,ierr)
         else
            disp = size_of_header+coord_r*size_of_data_per_rank
            call MPI_FILE_SET_VIEW(graph_mpi_fh,disp,&
                 & MPI_CHARACTER,MPI_CHARACTER,"external32",MPI_INFO_NULL,ierr)
         end if

         call MPI_FILE_GET_VIEW(graph_mpi_fh,disp,etype,filetype,datarep,ierr)

         bytes_written = 0
         !-- Write header & colatitudes for n_r=0:
         if ( rank == 0 ) then
            !-------- Write parameters:
            call MPI_FILE_WRITE(graph_mpi_fh,len(version),1,MPI_INTEGER,status,ierr)
            !call mpi_get_count(status,MPI_INTEGER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_INTEGER
            call MPI_FILE_WRITE(graph_mpi_fh,version,len(version), &
                                MPI_CHARACTER,status,ierr)
            !call mpi_get_count(status,MPI_CHARACTER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_CHARACTER
            call MPI_FILE_WRITE(graph_mpi_fh,len(version),1,MPI_INTEGER,status,ierr)
            !call mpi_get_count(status,MPI_INTEGER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_INTEGER

            call MPI_FILE_WRITE(graph_mpi_fh,len(runid),1,MPI_INTEGER,status,ierr)
            !call mpi_get_count(status,MPI_INTEGER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_INTEGER
            call MPI_FILE_WRITE(graph_mpi_fh,runid,len(runid), &
                                MPI_CHARACTER,status,ierr)
            !call mpi_get_count(status,MPI_CHARACTER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_CHARACTER
            call MPI_FILE_WRITE(graph_mpi_fh,len(runid),1,MPI_INTEGER,status,ierr)
            !call mpi_get_count(status,MPI_INTEGER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_INTEGER

            call MPI_FILE_WRITE(graph_mpi_fh,13*4,1,MPI_INTEGER,status,ierr)
            !call mpi_get_count(status,MPI_INTEGER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_INTEGER
            call MPI_FILE_WRITE(graph_mpi_fh,real(time,outp),1,MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(n_r_max,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(n_theta_max,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(n_phi_tot,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(n_r_ic_max-1,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(minc,outp),1,MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(nThetaBs,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(ra,outp),1,MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(ek,outp),1,MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(pr,outp),1,MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(prmag,outp),1,MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(radratio,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,real(sigma_ratio,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            call MPI_FILE_WRITE(graph_mpi_fh,13*4,1,MPI_INTEGER,status,ierr)
            !call mpi_get_count(status,MPI_INTEGER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_INTEGER

            !-------- Write colatitudes:
            call MPI_FILE_WRITE(graph_mpi_fh,n_theta_max*SIZEOF_OUT_REAL,1, &
                                MPI_INTEGER,status,ierr)
            !call mpi_get_count(status,MPI_INTEGER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_INTEGER
            do n_theta=1,n_theta_max
               call MPI_FILE_WRITE(graph_mpi_fh,real(theta_ord(n_theta),outp),1, &
                                   MPI_OUT_REAL,status,ierr)
               !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
               !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
            end do
            call MPI_FILE_WRITE(graph_mpi_fh,n_theta_max*SIZEOF_OUT_REAL,1, &
                                MPI_INTEGER,status,ierr)
            !call mpi_get_count(status,MPI_INTEGER,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_INTEGER

         end if
         lGraphHeader=.false.
         !PRINT*,"For the header, we wrote ",bytes_written," bytes."
      else  ! Call not for writing header

         !PERFON('mw_data')
         bytes_written=0

         !-- Determine radius and thetas in this block:
         n_theta_stop=n_theta_start+n_theta_block_size-1
         call MPI_FILE_WRITE(graph_mpi_fh,4*SIZEOF_OUT_REAL,1,MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER
         call MPI_FILE_WRITE(graph_mpi_fh,real(n_r-1,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(r(n_r)/r(1),outp),1, &
              &              MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(n_theta_start,outp),1, &
              &              MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(n_theta_stop,outp),1, &
              &              MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,4*SIZEOF_OUT_REAL,1,MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER

         !-- Write entropy:
         do n_theta=1,n_theta_block_size,2
            do n_phi=1,n_phi_max ! do loop over phis
               dummy(n_phi,n_theta)  =real(sr(n_phi,n_theta),kind=outp)   ! NHS
               dummy(n_phi,n_theta+1)=real(sr(n_phi,n_theta+1),kind=outp) ! SHS
            end do
         end do
         call graph_write_mpi(n_phi_max,n_theta_block_size,dummy,graph_mpi_fh)

         !-- Calculate and write radial velocity:
         fac=or2(n_r)*vScale*orho1(n_r)
         do n_theta=1,n_theta_block_size,2
            do n_phi=1,n_phi_max
               dummy(n_phi,n_theta)  =real(fac*vr(n_phi,n_theta),kind=outp)
               dummy(n_phi,n_theta+1)=real(fac*vr(n_phi,n_theta+1),kind=outp)
            end do
         end do
         call graph_write_mpi(n_phi_max,n_theta_block_size,dummy,graph_mpi_fh)

         !-- Calculate and write latitudinal velocity:
         fac_r=or1(n_r)*vScale*orho1(n_r)
         do n_theta=1,n_theta_block_size,2
            n_theta_cal=n_theta_start+n_theta-1
            fac=fac_r*O_sin_theta(n_theta_cal)
            do n_phi=1,n_phi_max
               dummy(n_phi,n_theta)  =real(fac*vt(n_phi,n_theta),kind=outp)
               dummy(n_phi,n_theta+1)=real(fac*vt(n_phi,n_theta+1),kind=outp)
            end do
         end do
         call graph_write_mpi(n_phi_max,n_theta_block_size,dummy,graph_mpi_fh)

         !-- Calculate and write longitudinal velocity:
         fac_r=or1(n_r)*vScale*orho1(n_r)
         do n_theta=1,n_theta_block_size,2
            n_theta_cal=n_theta_start+n_theta-1
            fac=fac_r*O_sin_theta(n_theta_cal)
            do n_phi=1,n_phi_max
               dummy(n_phi,n_theta)  =real(fac*vp(n_phi,n_theta),kind=outp)
               dummy(n_phi,n_theta+1)=real(fac*vp(n_phi,n_theta+1),kind=outp)
            end do
         end do
         call graph_write_mpi(n_phi_max,n_theta_block_size,dummy,graph_mpi_fh)

         !-- Write composition:
         if ( version == 'Graphout_Version_11' .or. version == 'Graphout_Version_12' ) then
            do n_theta=1,n_theta_block_size,2
               do n_phi=1,n_phi_max ! do loop over phis
                  dummy(n_phi,n_theta)  =real(xir(n_phi,n_theta),kind=outp)   ! NHS
                  dummy(n_phi,n_theta+1)=real(xir(n_phi,n_theta+1),kind=outp) ! SHS
               end do
            end do
            call graph_write_mpi(n_phi_max,n_theta_block_size,dummy,graph_mpi_fh)
         end if

         !-- Write pressure:
         if ( version == 'Graphout_Version_10' .or. version == 'Graphout_Version_12' ) then
            do n_theta=1,n_theta_block_size,2
               do n_phi=1,n_phi_max ! do loop over phis
                  dummy(n_phi,n_theta)  =real(prer(n_phi,n_theta),kind=outp)   ! NHS
                  dummy(n_phi,n_theta+1)=real(prer(n_phi,n_theta+1),kind=outp) ! SHS
               end do
            end do
            call graph_write_mpi(n_phi_max,n_theta_block_size,dummy,graph_mpi_fh)
         end if

         if ( l_mag ) then

            !-- Calculate and write radial magnetic field:
            fac=or2(n_r)
            do n_theta=1,n_theta_block_size,2
               do n_phi=1,n_phi_max
                  dummy(n_phi,n_theta)  =real(fac*br(n_phi,n_theta),kind=outp)
                  dummy(n_phi,n_theta+1)=real(fac*br(n_phi,n_theta+1),kind=outp)
               end do
            end do
            call graph_write_mpi(n_phi_max,n_theta_block_size,dummy,graph_mpi_fh)

            !-- Calculate and write latitudinal magnetic field:
            do n_theta=1,n_theta_block_size,2
               n_theta_cal=n_theta_start+n_theta-1
               fac=or1(n_r)*O_sin_theta(n_theta_cal)
               do n_phi=1,n_phi_max
                  dummy(n_phi,n_theta)  =real(fac*bt(n_phi,n_theta),kind=outp)
                  dummy(n_phi,n_theta+1)=real(fac*bt(n_phi,n_theta+1),kind=outp)
               end do
            end do
            call graph_write_mpi(n_phi_max,n_theta_block_size,dummy,graph_mpi_fh)

            !-- Calculate and write longitudinal magnetic field:
            do n_theta=1,n_theta_block_size,2
               n_theta_cal=n_theta_start+n_theta-1
               fac=or1(n_r)*O_sin_theta(n_theta_cal)
               do n_phi=1,n_phi_max
                  dummy(n_phi,n_theta)  =real(fac*bp(n_phi,n_theta),kind=outp)
                  dummy(n_phi,n_theta+1)=real(fac*bp(n_phi,n_theta+1),kind=outp)
               end do
            end do
            call graph_write_mpi(n_phi_max,n_theta_block_size,dummy,graph_mpi_fh)

         end if ! l_mag ?

         !write(*,"(A,I8)") "bytes_written = ",bytes_written

         !PERFOFF
      end if
      !$OMP END CRITICAL
   end subroutine graphOut_mpi
!----------------------------------------------------------------------------
   subroutine graphOut_mpi_header(time,n_r,n_theta_start,n_theta_block_size)
      !
      ! Writes the header (MPI version)
      !

      !-- Input variables:
      real(cp), intent(in) :: time
      integer,  intent(in) :: n_r                    ! radial grod point no.
      integer,  intent(in) :: n_theta_start          ! start theta no.
      integer,  intent(in) :: n_theta_block_size     ! size of theta block

      !-- Local variables:
      integer :: n_theta       ! counter for colatitude
      character(len=20) :: version

      !-- MPI related variables
      integer :: status(MPI_STATUS_SIZE)
      integer :: bytes_written
      integer :: size_of_header, size_of_data_per_rank, size_of_data_per_r
      integer :: size_of_data_per_thetaB
      integer(kind=MPI_OFFSET_kind) :: disp
      integer :: etype,filetype
      character(len=MPI_MAX_DATAREP_STRING) :: datarep
      ! end of MPI related variables

      !----- Unformatted output:
      if ( l_chemical_conv ) then
         if ( l_PressGraph ) then
            version='Graphout_Version_12'
         else
            version='Graphout_Version_11'
         end if
      else
         if ( l_PressGraph ) then
            version='Graphout_Version_10'
         else
            version='Graphout_Version_9'
         end if
      end if

      size_of_header = 8+len(version)+8+len(runid)+8+13*SIZEOF_INTEGER+8+ &
                       n_theta_max*SIZEOF_OUT_REAL

#ifdef ONE_LARGE_BLOCK
      size_of_data_per_thetaB = 8+4*SIZEOF_OUT_REAL+4* &
                                (8+n_phi_max*SIZEOF_OUT_REAL*n_theta_block_size)
      if ( version=='Graphout_Version_10' .or. version=='Graphout_Version_11') then
         size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                   (8+n_phi_max*SIZEOF_OUT_REAL*n_theta_block_size)
      else if ( version=='Graphout_Version_12') then
         size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                   2*(8+n_phi_max*SIZEOF_OUT_REAL*n_theta_block_size)
      end if


      if ( l_mag ) size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                   3*(8+n_phi_max*SIZEOF_OUT_REAL*n_theta_block_size)
#else
      size_of_data_per_thetaB = 8+4*SIZEOF_OUT_REAL+4* &
                               (8+n_phi_max*SIZEOF_OUT_REAL)*n_theta_block_size
      if ( version=='Graphout_Version_10' .or. version=='Graphout_Version_11') then
         size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                   (8+n_phi_max*SIZEOF_OUT_REAL)*n_theta_block_size
      else if ( version=='Graphout_Version_12') then
         size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                   2*(8+n_phi_max*SIZEOF_OUT_REAL)*n_theta_block_size
      end if
      if ( l_mag ) size_of_data_per_thetaB = size_of_data_per_thetaB + &
                                           3*(8+n_phi_max*SIZEOF_OUT_REAL)*n_theta_block_size
#endif
      size_of_data_per_r = size_of_data_per_thetaB * nThetaBs
      size_of_data_per_rank = size_of_data_per_r * nR_per_rank

      if ( rank == 0 ) then
         ! coord_r zero writes the Header
         disp = 0
         call MPI_FILE_SET_VIEW(graph_mpi_fh,disp,MPI_CHARACTER, &
                                MPI_CHARACTER,"external32",MPI_INFO_NULL,ierr)
      else
         disp = size_of_header+coord_r*size_of_data_per_rank
         call MPI_FILE_SET_VIEW(graph_mpi_fh,disp,&
              & MPI_CHARACTER,MPI_CHARACTER,"external32",MPI_INFO_NULL,ierr)
      end if

      call mpi_file_get_view(graph_mpi_fh,disp,etype,filetype,datarep,ierr)

      bytes_written = 0
      !-- Write header & colatitudes for n_r=0:
      if ( rank == 0 ) then

         !-------- Write parameters:
         call MPI_FILE_WRITE(graph_mpi_fh,len(version),1,MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER
         call MPI_FILE_WRITE(graph_mpi_fh,version,len(version), &
                             MPI_CHARACTER,status,ierr)
         !call mpi_get_count(status,MPI_CHARACTER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_CHARACTER
         call MPI_FILE_WRITE(graph_mpi_fh,len(version),1,MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER

         call MPI_FILE_WRITE(graph_mpi_fh,len(runid),1,MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER
         call MPI_FILE_WRITE(graph_mpi_fh,runid,len(runid), &
                             MPI_CHARACTER,status,ierr)
         !call mpi_get_count(status,MPI_CHARACTER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_CHARACTER
         call MPI_FILE_WRITE(graph_mpi_fh,len(runid),1,MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER

         call MPI_FILE_WRITE(graph_mpi_fh,13*4,1,MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER
         call MPI_FILE_WRITE(graph_mpi_fh,real(time,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(n_r_max,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(n_theta_max,outp),1, &
                             MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(n_phi_tot,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(n_r_ic_max-1,outp),1, &
                             MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(minc,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(nThetaBs,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(ra,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(ek,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(pr,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(prmag,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(radratio,outp),1,MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,real(sigma_ratio,outp),1, &
              &              MPI_OUT_REAL,status,ierr)
         !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         call MPI_FILE_WRITE(graph_mpi_fh,13*4,1,MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER

         !-------- Write colatitudes:
         call MPI_FILE_WRITE(graph_mpi_fh,n_theta_max*SIZEOF_OUT_REAL,1, &
                             MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER
         do n_theta=1,n_theta_max
            call MPI_FILE_WRITE(graph_mpi_fh,real(theta_ord(n_theta),outp),1, &
                                MPI_OUT_REAL,status,ierr)
            !call mpi_get_count(status,MPI_OUT_REAL,count,ierr)
            !bytes_written = bytes_written + count*SIZEOF_OUT_REAL
         end do
         call MPI_FILE_WRITE(graph_mpi_fh,n_theta_max*SIZEOF_OUT_REAL,1, &
                             MPI_INTEGER,status,ierr)
         !call mpi_get_count(status,MPI_INTEGER,count,ierr)
         !bytes_written = bytes_written + count*SIZEOF_INTEGER

      end if

   end subroutine graphOut_mpi_header
#endif
!----------------------------------------------------------------------------
   subroutine graphOut_IC(b_ic,db_ic,ddb_ic,aj_ic,dj_ic,bICB)
      !
      !  Purpose of this subroutine is to write inner core magnetic       
      !  field onto graphic output file. If the inner core is             
      !  insulating (l_cond_ic=false) the potential field is calculated   
      !  from the outer core field at r=r_cmb.                            
      !  This version assumes that the fields are fully local on the coord_r 
      !  which is calling this routine (usually coord_r 0).                  
      !

      !-- Input variables:
      complex(cp), intent(in) :: b_ic(lm_maxMag,n_r_ic_maxMag)
      complex(cp), intent(in) :: db_ic(lm_maxMag,n_r_ic_maxMag)
      complex(cp), intent(in) :: ddb_ic(lm_maxMag,n_r_ic_maxMag)
      complex(cp), intent(in) :: aj_ic(lm_maxMag,n_r_ic_maxMag)
      complex(cp), intent(in) :: dj_ic(lm_maxMag,n_r_ic_maxMag)
      complex(cp), intent(in) :: bICB(lm_maxMag)
    
      !-- Local variables:
      integer :: nR
      integer :: nThetaB,nTheta,nThetaStart,nThetaC
      integer :: nPhi
    
      complex(cp) :: dLhb(lm_max)
      complex(cp) :: bhG(lm_max)
      complex(cp) :: bhC(lm_max)
      complex(cp) :: dLhj(lm_max)
      complex(cp) :: cbhG(lm_max)
      complex(cp) :: cbhC(lm_max)
      real(cp) :: BrB(nrp,nfs)
      real(cp) :: BtB(nrp,nfs)
      real(cp) :: BpB(nrp,nfs)
      real(outp) :: Br(n_phi_max,n_theta_max)
      real(outp) :: Bt(n_phi_max,n_theta_max)
      real(outp) :: Bp(n_phi_max,n_theta_max)
    
#ifdef WITH_MPI
      ! MPI specific variables
      integer :: status(MPI_STATUS_SIZE)
      ! end MPI variables
#endif

      !-- Loop over all radial levels:
    
      do nR=2,n_r_ic_max  ! nR=1 is ICB
    
         if ( l_cond_ic ) then
            call legPrep_IC(b_ic(1,nR),db_ic(1,nR),ddb_ic(1,nR), &
                 &          aj_ic(1,nR),dj_ic(1,nR),dLh,lm_max,  &
                 &          l_max,minc,r_ic(nR),r_ICB,.false.,   &
                 &          .true.,l_cond_ic,dLhb,bhG,bhC,dLhj,  &
                 &          cbhG,cbhC)
         else
            call legPrep_IC(bICB(:),db_ic(1,1),ddb_ic(1,1),aj_ic(1,1), &
                 &          dj_ic(1,1),dLh,lm_max,l_max,minc,r_ic(nR), &
                 &          r_ICB,.false.,.true.,l_cond_ic,dLhb,bhG,   &
                 &          bhC,dLhj,cbhG,cbhC)
         end if
    
#ifdef WITH_SHTNS
         if ( l_cond_ic ) then
            call torpol_to_spat(b_ic(:, nR), db_ic(:, nR), aj_ic(:, nR), &
                 &              BrB, BtB, BpB)
         else
            call torpol_to_spat(bICB(:), db_ic(:, 1), aj_ic(:, 1), &
                 &              BrB, BtB, BpB)
         end if
#endif
         do nThetaB=1,nThetaBs
            nThetaStart=(nThetaB-1)*sizeThetaB+1
    
#ifndef WITH_SHTNS
            !------ Preform Legendre transform:
            call legTF(dLhb,bhG,bhC,dLhj,cbhG,cbhC, &
                 l_max,minc,nThetaStart,sizeThetaB, &
                 Plm,dPlm,.true.,.false., &
                 BrB,BtB,BpB,BrB,BrB,BrB)
    
            if ( .not. l_axi ) then
               call fft_thetab(BrB,1)
               call fft_thetab(BtB,1)
               call fft_thetab(BpB,1)
            end if
#endif
    
            !------ Copy theta block and calculate real components:
            do nTheta=1,sizeThetaB
               nThetaC=nThetaStart-1+nTheta
               do nPhi=1,n_phi_max
                  Br(nPhi,nThetaC)=real(BrB(nPhi,nTheta)*O_r_ic2(nR),kind=outp)
                  Bt(nPhi,nThetaC)=real(BtB(nPhi,nTheta)*O_r_ic(nR) * &
                       O_sin_theta(nThetaC),kind=outp)
                  Bp(nPhi,nThetaC)=real(BpB(nPhi,nTheta)*O_r_ic(nR) * &
                       O_sin_theta(nThetaC),kind=outp)
               end do
            end do
    
         end do
    
    
#ifdef WITH_MPI
         ! in process n_procs_r-1 the last oc fields have been written,
         ! Now just append on this process.
         if ( coord_r == n_procs_r-1 ) then
            call MPI_FILE_WRITE(graph_mpi_fh,4*4,1,MPI_INTEGER,status,ierr)
            call MPI_FILE_WRITE(graph_mpi_fh,real(n_r_max+nR-2,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            call MPI_FILE_WRITE(graph_mpi_fh,real(r_ic(nR)/r_cmb,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            call MPI_FILE_WRITE(graph_mpi_fh,1.e0_outp,1,MPI_OUT_REAL,status,ierr)
            call MPI_FILE_WRITE(graph_mpi_fh,real(n_theta_max,outp),1, &
                                MPI_OUT_REAL,status,ierr)
            call MPI_FILE_WRITE(graph_mpi_fh,4*4,1,MPI_INTEGER,status,ierr)
         end if
#else
         write(n_graph_file) real(n_r_max+nR-2,outp),real(r_ic(nR)/r_cmb,outp), &
              &              1.e0_outp,real(n_theta_max,outp)
#endif


         !-- Write radial magnetic field:
#ifdef WITH_MPI
         if (coord_r == n_procs_r-1) then
            call graph_write_mpi(n_phi_max,n_theta_max,Br,graph_mpi_fh)
         end if
#else
         call graph_write(n_phi_max,n_theta_max,Br,n_graph_file)
#endif

         !-- Write latitudinal magnetic field:
#ifdef WITH_MPI
         if (coord_r == n_procs_r-1) then
            call graph_write_mpi(n_phi_max,n_theta_max,Bt,graph_mpi_fh)
         end if
#else
         call graph_write(n_phi_max,n_theta_max,Bt,n_graph_file)
#endif
  
         !-- Write longitudinal magnetic field:
#ifdef WITH_MPI
         if (coord_r == n_procs_r-1) then
            call graph_write_mpi(n_phi_max,n_theta_max,Bp,graph_mpi_fh)
         end if
#else
         call graph_write(n_phi_max,n_theta_max,Bp,n_graph_file)
#endif

      end do  ! Do loop over radial levels nR


   end subroutine graphOut_IC
!-----------------------------------------------------------------------
   subroutine graph_write(n_phis,n_thetas,dummy,n_graph_file)
      !
      !  This subroutine writes the data for one theta-band
      !  (stored in 'dummy'). Version May, 5, 2000.
      !

      !-- Input variables:
      integer,    intent(in) :: n_thetas            ! number of first colatitude value
      integer,    intent(in) :: n_phis              ! number of logitudes to be printed
      real(outp), intent(in) :: dummy(n_phi_max,*)  ! data
      integer,    intent(in) :: n_graph_file        ! output unit

      !-- Local variables:
      integer :: n_phi,n_theta


      !PERFON('gwrite')
      do n_theta=1,n_thetas
         write(n_graph_file) (dummy(n_phi,n_theta),n_phi=1,n_phis)
      end do
      !PERFOFF

   end subroutine graph_write
!------------------------------------------------------------------------------
#ifdef WITH_MPI
   subroutine graph_write_mpi(n_phis,n_thetas,dummy,graph_mpi_fh)

      !-- Input variables
      integer,    intent(in) :: n_thetas          ! number of first colatitude value
      integer,    intent(in) :: n_phis            ! number of logitudes to be printed
      real(outp), intent(in) :: dummy(n_phi_max,*)! data
      integer,    intent(in) :: graph_mpi_fh      ! mpi handle of the mpi file

      !-- Local variables:
      integer :: n_theta

      !-- MPI related variables
      integer :: status(MPI_STATUS_SIZE), count
      integer(kind=MPI_OFFSET_KIND) :: offset

#ifdef ONE_LARGE_BLOCK
      call MPI_FILE_WRITE(graph_mpi_fh,n_phis*n_thetas*SIZEOF_OUT_REAL,1, &
                          MPI_INTEGER,status,ierr)
      ! call MPI_FILE_WRITE(graph_mpi_fh,dummy(:,1:n_thetas),n_phis*n_thetas, &
      !                     MPI_OUT_REAL,status,ierr)
      count = 0
      do while (n_phis*n_thetas /= count)
          offset = -count*SIZEOF_OUT_REAL
          if (count /= 0 ) call MPI_File_seek(graph_mpi_fh, offset, MPI_SEEK_CUR, ierr)
          call MPI_File_write(graph_mpi_fh,dummy(:,1:n_thetas),n_phis*n_thetas, &
          MPI_OUT_REAL,status,ierr)
          call MPI_Get_count(status, MPI_OUT_REAL, count, ierr)
      enddo
      call MPI_FILE_WRITE(graph_mpi_fh,n_phis*n_thetas*SIZEOF_OUT_REAL,1, &
                          MPI_INTEGER,status,ierr)
#else
      !PERFON('gwrite_M')
      do n_theta=1,n_thetas

         call MPI_FILE_WRITE(graph_mpi_fh,n_phis*SIZEOF_OUT_REAL,1, &
                             MPI_INTEGER,status,ierr)
         call MPI_FILE_WRITE(graph_mpi_fh,dummy(1,n_theta),n_phis, &
                             MPI_OUT_REAL,status,ierr)
         call MPI_FILE_WRITE(graph_mpi_fh,n_phis*SIZEOF_OUT_REAL,1, &
                             MPI_INTEGER,status,ierr)

            !call MPI_FILE_WRITE(n_graph_file) &
            !      (dummy(n_phi,n_theta),n_phi=1,n_phis)

      end do
      !PERFOFF

#endif
   end subroutine graph_write_mpi
#endif
!----------------------------------------------------------------------------
end module graphOut_mod

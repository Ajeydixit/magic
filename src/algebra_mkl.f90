module algebra

   use precision_mod, only: cp

   use lapack95, only: getrs, getrf

   implicit none

   private

   logical :: multiple_rhs = .true.   ! read the comment in cgeslML subroutine!
   public :: sgefa, sgesl, cgesl, cgeslML

contains

   subroutine cgesl(a,len_a,n,pivot,rhs)
      !
      !  This routine does the backward substitution into a lu-decomposed real 
      !  matrix a (to solve a * x = bc1) were bc1 is the right hand side  
      !  vector. On return x is stored in bc1.                            
      !                                                                     

      !-- Input variables:
      integer,  intent(in) :: n          ! dimension of problem
      integer,  intent(in) :: len_a      ! first dim of a
      integer,  intent(in) :: pivot(n)   ! pivot pointer of legth n
      real(cp), intent(in) :: a(len_a,n) ! real n X n matrix

      !-- Output variables
      complex(cp), intent(inout) :: rhs(n) ! on input RHS of problem

      call getrs(cmplx(a,0.0_cp,kind=cp),pivot,rhs)

   end subroutine cgesl
!-----------------------------------------------------------------------------
   subroutine cgeslML(a,len_a,n,pivot,rhs,nRHSs)
      !
      !  This routine does the backward substitution into a lu-decomposed real
      !  matrix a (to solve a * x = bc ) simultaneously for nRHSs complex 
      !  vectors bc. On return the results are stored in the bc.                  
      !

      !-- Input variables:
      integer,  intent(in) :: n           ! dimension of problem
      integer,  intent(in) :: len_a       ! leading dimension of a
      integer,  intent(in) :: pivot(n)    ! pivot pointer of length n
      real(cp), intent(in) :: a(len_a,n)  ! real n X n matrix
      integer,  intent(in) :: nRHSs       ! number of right-hand sides

      complex(cp), intent(inout) :: rhs(:,:) ! on input RHS of problem
      
      complex(cp), allocatable :: tmp_rhs(:,:)
      integer :: i
      
      if (multiple_rhs) then
         call getrs(cmplx(a(1:n,1:n),0.0_cp,kind=cp),pivot(1:n),rhs(1:n,:))
      else
         ! When using multiple RHS, MKL will compute slightly different 
         ! solutions if you batch the RHS together e.g. solving for 
         ! [x1, x2] or for [x1, x3] will give slightly different x1
         ! Setting "multiple_rhs" flag to "false" will allow you to test
         ! if this changes some precision in your code or not
         allocate(tmp_rhs(n,1))
         do i=1,nRHSs
            tmp_rhs(1:n,1) = rhs(1:n,i)
            call getrs(cmplx(a(1:n,1:n),0.0_cp,kind=cp),pivot(1:n),tmp_rhs)
            rhs(1:n,i) = tmp_rhs(1:n,1)
         end do
         deallocate(tmp_rhs)
      end if

   end subroutine cgeslML
!-----------------------------------------------------------------------------
   subroutine sgesl(a,len_a,n,pivot,rhs)
      !
      !     like the linpack routine
      !     backward substitution of vector b into lu-decomposed matrix a
      !     to solve  a * x = b for a single real vector b
      !
      !     sub sgefa must be called once first to initialize a and pivot
      !

      !-- Input variables:
      integer,  intent(in) :: n         ! dim of problem
      integer,  intent(in) :: len_a     ! first dim of a
      integer,  intent(in) :: pivot(n)  ! pivot information
      real(cp), intent(in) :: a(len_a,n)

      !-- Output: solution stored in rhs(n)
      real(cp), intent(inout) :: rhs(n)

      call getrs(a,pivot,rhs)

   end subroutine sgesl
!-----------------------------------------------------------------------------
   subroutine sgefa(a,len_a,n,pivot,info)
      !
      !     like the linpack routine
      !
      !     lu decomposes the real matrix a(n,n) via gaussian elimination
      !

      !-- Input variables:
      integer,  intent(in) :: len_a,n
      real(cp), intent(inout) :: a(len_a,n)

      !-- Output variables:
      integer, intent(out) :: pivot(n)   ! pivoting information
      integer, intent(out) :: info

      call getrf(a(1:n,1:n),pivot(1:n),info)

   end subroutine sgefa
!-----------------------------------------------------------------------------
end module algebra

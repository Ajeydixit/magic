module geometry
   !
   !   This module defines how the points from Grid Space, LM-Space and 
   !   ML-Space are divided amonst the MPI domains.
   !   
   !   This does *not* include mappings, only lower/upper bounds and 
   !   dimensions.
   ! 
   !   PS: is "truncation" still a fitting name for this module?
   !

   use precision_mod, only: cp
   use logic
   use useful, only: abortRun
   use parallel_mod
   use mpi
   
   implicit none
   
   public

   !---------------------------------
   !-- Global Dimensions:
   !---------------------------------
   !   
   !   minc here is sort of the inverse of mres in SHTns. In MagIC, the number
   !   of m modes stored is m_max/minc+1. In SHTns, it is simply m_max. 
   !   Conversely, there are m_max m modes in MagIC, though not all of them are 
   !   effectivelly stored/computed. In SHTns, the number of m modes is 
   !   m_max*minc+1 (therein called mres). This makes things very confusing 
   !   specially because lm2 and lmP2 arrays (and their relatives) store m_max 
   !   m points, and sets those which are not multiple of minc to 0.
   !   
   !   In other words, this:
   !   > call shtns_lmidx(lm_idx, l_idx, m_idx/minc)
   !   returns the same as 
   !   > lm_idx = lm2(l_idx, m_idx)
   !   
   !-- TODO: ask Thomas about converting all variables associated with the 
   !   global geometry (e.g. n_r_max, n_phi_max) to the "glb" suffix
   !   (e.g. n_r_glb, n_phi_glb). I find it more intuitive, but 
   !   
   
   !-- Basic quantities:
   integer :: n_r_max       ! number of radial grid points
   integer :: n_cheb_max    ! max degree-1 of cheb polynomia
   integer :: n_phi_tot     ! number of longitude grid points
   integer :: n_r_ic_max    ! number of grid points in inner core
   integer :: n_cheb_ic_max ! number of chebs in inner core
   integer :: minc          ! basic wavenumber, longitude symmetry  
   integer :: nalias        ! controls dealiasing in latitude
   logical :: l_axi         ! logical for axisymmetric calculations
   character(len=72) :: radial_scheme ! radial scheme (either Cheybev of FD)
   real(cp) :: fd_stretch    ! regular intervals over irregular intervals
   real(cp) :: fd_ratio      ! drMin over drMax (only when FD are used)
   integer :: fd_order       ! Finite difference order (for now only 2 and 4 are safe)
   integer :: fd_order_bound ! Finite difference order on the  boundaries
   integer :: n_r_cmb        ! Used to belong to radial_data
   integer :: n_r_icb        ! Used to belong to radial_data
   integer :: n_r_on_last_rank ! Used to belong to radial_data
 
   !-- Derived quantities:
   integer :: n_phi_max   ! absolute number of phi grid-points
   integer :: n_theta_max ! number of theta grid-points
   integer :: n_theta_axi ! number of theta grid-points (axisymmetric models)
   integer :: l_max       ! max degree of Plms
   integer :: m_max       ! max order of Plms
   integer :: n_m_max     ! max number of ms (different orders) = m_max/minc+1
   integer :: lm_max      ! number of l/m combinations
   integer :: lmP_max     ! number of l/m combination if l runs to l_max+1
   integer :: lm_max_real ! number of l/m combination for real representation (cos/sin)
   integer :: nrp         ! dimension of phi points in for real arrays
   integer :: n_r_tot     ! total number of radial grid points
 
   !-- Now quantities for magnetic fields:
   !   Set lMag=0 if you want to save this memory (see c_fields)!
   integer :: lMagMem       ! Memory for magnetic field calculation
   integer :: n_r_maxMag    ! Number of radial points to calculate magnetic field
   integer :: n_r_ic_maxMag ! Number of radial points to calculate IC magnetic field
   integer :: n_r_totMag    ! n_r_maxMag + n_r_ic_maxMag
   integer :: l_maxMag      ! Max. degree for magnetic field calculation
   integer :: lm_maxMag     ! Max. number of l/m combinations for magnetic field calculation
 
   !-- Movie memory control:
   integer :: lMovieMem      ! Memory for movies
   integer :: ldtBMem        ! Memory for movie output
   integer :: lm_max_dtB     ! Number of l/m combinations for movie output
   integer :: n_r_max_dtB    ! Number of radial points for movie output
   integer :: n_r_ic_max_dtB ! Number of IC radial points for movie output
   integer :: lmP_max_dtB    ! Number of l/m combinations for movie output if l runs to l_max+1
 
   !-- Memory control for stress output:
   integer :: lStressMem     ! Memory for stress output
   integer :: n_r_maxStr     ! Number of radial points for stress output
   integer :: n_theta_maxStr ! Number of theta points for stress output
   integer :: n_phi_maxStr   ! Number of phi points for stress output
   
   !---------------------------------
   !-- Distributed Dimensions
   !---------------------------------
   !  
   !   Notation for continuous variables:
   !   dist_V(i,1) = lower bound of direction V in rank i
   !   dist_V(i,2) = upper bound of direction V in rank i
   !   dist_V(i,0) = shortcut to dist_V(i,2) - dist_V(i,1) + 1
   !   
   !   Because continuous variables are simple, we can define some shortcuts:
   !   l_V: dist_V(this_rank,1)
   !   u_V: dist_V(this_rank,2)
   !   n_V_loc: u_V - l_V + 1  (number of local points in V direction)
   !   n_V_max: global dimensions of variable V. Basically, the result of 
   !   > MPI_ALLREDUCE(n_V_loc,n_V_max,MPI_SUM)
   !   
   !   For discontinuous variables:
   !   dist_V(i,0)  = how many V points are there for rank i
   !   dist_V(i,1:) = an array containing all of the V points in rank i. Since
   !      the number of points is not necessarily the same in all ranks, make
   !      sure that all points of rank i are in dist_V(i,1:n_V_loc) and the
   !      remaining dist_V(i,n_V_loc+1:) points are set to a negative number.
   !      
   !   Notice that n_lm_loc, n_lmP_loc and etc are not the same as lm_max and lmP_max.
   !   The former stores the number of *local* points, the later stores the 
   !   total number of points in all ranks.
   !   
   !   Notice that n_lm, n_lmP and etc are not the same as lm_max and lmP_max.
   !   The former stores the number of *local* points, the later stores the 
   !   total number of points in all ranks.
   !   

   !-- Distributed Grid Space 
   integer, allocatable, protected :: dist_theta(:,:)
   integer, allocatable, protected :: dist_r(:,:)
   integer, protected :: n_theta_loc, l_theta, u_theta
   integer, protected :: n_r_loc,     l_r,     u_r
   
   !   Helpers
   integer, protected :: l_r_Mag
   integer, protected :: l_r_Che
   integer, protected :: l_r_TP 
   integer, protected :: l_r_DC 
   integer, protected :: u_r_Mag 
   integer, protected :: u_r_Che 
   integer, protected :: u_r_TP  
   integer, protected :: u_r_DC  
   integer, protected :: n_lmMag_loc
   integer, protected :: n_lmChe_loc
   integer, protected :: n_lmTP_loc
   integer, protected :: n_lmDC_loc
   
   !-- Distributed LM-Space
   ! 
   !   Just for clarification:
   !   n_lm_loc:  total number of l and m points in this rank
   !   n_lmP_loc: total number of l and m points (for l_max+1) in this rank
   !   
   !   n_m_array: if m_max is not divisible by n_ranks_m, some ranks will 
   !          receive more m points than others. 
   !          n_m_array is basically MPI_ALLREDUCE(n_m_array,n_m_loc,MPI_MAX)
   !          It is also the size of the 2nd dimension of dist_m.
   !          Set the extra dist_m(i,1:n_m_loc) to the points in rank i and the 
   !          remaining dist_m(i,n_m_loc+1:n_m_array) to a negative number. 
   !   
   !        allocatable, protected :: dist_r(:,:) => same as dist_r from Grid Space
   integer, allocatable, protected :: dist_m(:,:)
   integer, allocatable, protected :: dist_n_lm(:)
   integer, allocatable, protected :: dist_n_lmP(:)
   integer, protected :: n_m_loc, n_lm_loc, n_lmP_loc
   integer, protected :: n_m_array
   
   !-- Distributed ML-Space
   !   
   !   The key variable here is dist_mlo. It contains the tuplets associated
   !   with each rank.
   !   
   !   dist_mlo(irank,j,1) = value of m in the j-th tuplet in irank.
   !   dist_mlo(irank,j,2) = value of l in the j-th tuplet in irank.
   !   
   !   Everything should be written such that the tuplets given in this array
   !   are respected. The code should be agnostic to what order or what criteria
   !   was chosen to build this variable. n_mlo_array gives the length of the 
   !   second dimension of this array.
   !   
   !   where_mlo(m,l): this merely returns the coord_mlo (or rank in the 
   !   comm_mlo) in which the tuplet (m,l) is allocated.
   !   
   !-- TODO: none of the code uses dist_mlo so far. This is the next step
   !-- TODO: dist_mlo is created in distribute_mlo, but this is rather poorly
   !   optimized. I'm afraid that a reasonable distribution would require a very
   !   complex routine which deals with graphs and trees.
   !
   integer, allocatable, protected :: dist_mlo(:,:,:)
   integer, allocatable, protected :: dist_n_mlo(:)
   integer, protected :: n_mo_loc, n_lo_loc, n_mlo_loc
   integer, protected :: n_mlo_array, mlo_max
   
   private :: distribute_gs, distribute_lm, distribute_mlo, &
              distribute_contiguous_first, distribute_contiguous_last, &
              distribute_discontiguous_roundrobin, &
              distribute_discontiguous_snake, &
              print_contiguous_distribution, print_discontiguous_distribution
   
contains
   
   !----------------------------------------------------------------------------
   subroutine initialize_global_geometry
      !   
      !   Author: .NOT. Rafael Lago!
      !   
      
      if ( .not. l_axi ) then
         ! absolute number of phi grid-points
         n_phi_max = n_phi_tot/minc

         ! number of theta grid-points
         n_theta_max = n_phi_tot/2

         ! max degree and order of Plms
         l_max = (nalias*n_theta_max)/30 
         m_max = (l_max/minc)*minc
      else
         n_theta_max = n_theta_axi
         n_phi_max   = 1
         n_phi_tot   = 1
         minc        = 1
         l_max       = (nalias*n_theta_max)/30 
         m_max       = 0
      end if
      
      ! max number of ms (different oders)
      n_m_max=m_max/minc+1
      
      ! number of l/m combinations
      lm_max=m_max*(l_max+1)/minc - m_max*(m_max-minc)/(2*minc)+(l_max+1-m_max)
      ! number of l/m combination if l runs to l_max+1
      lmP_max=lm_max+n_m_max
      
      ! number of l/m combination 
      ! for real representation (cos/sin)
      lm_max_real=2*lm_max
      
#if WITH_SHTNS
      nrp=n_phi_max
#else
      nrp=n_phi_max+2
#endif

      ! total number of radial grid points
      n_r_tot=n_r_max+n_r_ic_max
      
      !-- Now quantities for magnetic fields:
      !    Set lMag=0 if you want to save this memory (see c_fields)!
      n_r_maxMag    = max(1,lMagMem*n_r_max   )
      n_r_ic_maxMag = max(1,lMagMem*n_r_ic_max)
      n_r_totMag    = max(1,lMagMem*n_r_tot   )
      l_maxMag      = max(1,lMagMem*l_max     )
      lm_maxMag     = max(1,lMagMem*lm_max    )
      
      !-- Movie memory control:
      lm_max_dtB    =max(1, ldtBMem*lm_max    )
      lmP_max_dtB   =max(1, ldtBMem*lmP_max   )
      n_r_max_dtB   =max(1, ldtBMem*n_r_max   )
      n_r_ic_max_dtB=max(1, ldtBMem*n_r_ic_max)
      
      !-- Memory control for stress output:
      n_r_maxStr    = max(1, lStressMem*n_r_max    )
      n_theta_maxStr= max(1, lStressMem*n_theta_max)
      n_phi_maxStr  = max(1, lStressMem*n_phi_max  )
      
      !-- I don't know the purpose of these two variables, but they used to 
      !   belong to radial_data. I'll keep them around. - Lago
      n_r_cmb = 1
      n_r_icb = n_r_max
      
   end subroutine initialize_global_geometry
   
   !----------------------------------------------------------------------------
   subroutine initialize_distributed_geometry
      !   
      !   Author: Rafael Lago, MPCDF, June 2018
      !   
      
      call distribute_gs
      call print_contiguous_distribution(dist_theta, n_ranks_theta, 'θ')
      call print_contiguous_distribution(dist_r, n_ranks_r, 'r')
      
      call distribute_lm
      call print_discontiguous_distribution(dist_m, n_m_array, n_ranks_m, 'm')
      
      call distribute_mlo
      call print_mlo_distribution_summary
      call print_mlo_distribution
      
   end subroutine initialize_distributed_geometry
   
   !----------------------------------------------------------------------------
   subroutine finalize_geometry
      !   
      !   Author: Rafael Lago, MPCDF, June 2018
      !   
      
      !-- Finalize global geometry
      !   lol
      
      !-- Finalize distributed grid space
      deallocate(dist_theta)
      deallocate(dist_r)
      
      !-- Finalize distributed lm
      deallocate(dist_m)
      
      !-- Finalize distributed mlo
      deallocate(dist_mlo)
      deallocate(dist_n_mlo)
      
   end subroutine finalize_geometry
   
   !----------------------------------------------------------------------------
   subroutine distribute_gs
      !   
      !   Distributes the radial points and the θs. Every φ point is local.
      !   
      !   Author: Rafael Lago, MPCDF, June 2018
      !   
      
      !-- Distribute Grid Space θ
      !
      allocate(dist_theta(0:n_ranks_theta-1,0:2))
      call distribute_contiguous_last(dist_theta,n_theta_max,n_ranks_theta)
      dist_theta(:,0) = dist_theta(:,2) - dist_theta(:,1) + 1
      l_theta = dist_theta(coord_theta,1)
      u_theta = dist_theta(coord_theta,2)
      n_theta_loc = u_theta - l_theta + 1
      
      !-- Distribute Grid Space r
      !   I'm not sure what happens if n_r_cmb/=1 and n_r_icb/=n_r_max
      allocate(dist_r(0:n_ranks_r-1,0:2))
      call distribute_contiguous_last(dist_r,n_r_max,n_ranks_r)
      
      !-- Take n_r_cmb into account now
      !-- TODO check if this is correct
      dist_r(:,1:2) = dist_r(:,1:2) + n_r_cmb - 1
      
      dist_r(:,0) = dist_r(:,2) - dist_r(:,1) + 1
      n_r_loc = dist_r(coord_r,0)
      l_r = dist_r(coord_r,1)
      u_r = dist_r(coord_r,2)
      
      l_r_Mag = 1
      l_r_Che = 1
      l_r_TP  = 1
      l_r_DC  = 1
      u_r_Mag = 1
      u_r_Che = 1
      u_r_TP  = 1
      u_r_DC  = 1
      if (l_mag          ) l_r_Mag = l_r
      if (l_chemical_conv) l_r_Che = l_r
      if (l_TP_form      ) l_r_TP  = l_r
      if (l_double_curl  ) l_r_DC  = l_r
      if (l_mag          ) u_r_Mag = u_r
      if (l_chemical_conv) u_r_Che = u_r
      if (l_TP_form      ) u_r_TP  = u_r
      if (l_double_curl  ) u_r_DC  = u_r
      
   end subroutine distribute_gs
   
   !----------------------------------------------------------------------------
   subroutine distribute_lm
      !   
      !   Distributes the m's from the LM-space. It re-uses the distribution
      !   of the radial points obtained from distribute_gs. Every l point is
      !   local.
      !   
      !   Author: Rafael Lago, MPCDF, June 2018
      !   
      
      n_m_array = ceiling(real(n_m_max) / real(n_ranks_m))
      allocate(dist_m(0:n_ranks_m-1, 0:n_m_array))
      allocate(dist_n_lm(0:n_ranks_m-1))
      allocate(dist_n_lmP(0:n_ranks_m-1))
      
      call distribute_discontiguous_snake(dist_m, n_m_array, n_m_max, n_ranks_m)
      
      !-- The function above distributes a list of points [p1, p2, (...), pN].
      !   Now we resolve what those points mean in practice. In this case
      !   it is pretty simple: p(x) = (x-1)*minc
      dist_m(:,1:) = (dist_m(:,1:)-1)*minc
      
      !-- Counts how many points were assigned to each rank
      dist_m(:,0) = count(dist_m(:,1:) >= 0, 2)
      
      !-- Formula for the number of lm-points in each rank:
      !   n_lm = Σ(l_max+1 - m) = (l_max+1)*n_m - Σm
      !   for every m in the specified rank. Read the
      !   comment in "Distributed LM-Space" section at the beginning of this 
      !   module for more details on that
      dist_n_lm = (l_max+1)*dist_m(:,0) - sum(dist_m(:,1:), dim=2, mask=dist_m(:,1:)>=0)
      dist_n_lmP = dist_n_lm + dist_m(:,0)       
      
      n_m_loc   = dist_m(coord_m,0)
      n_lm_loc  = dist_n_lm(coord_m)
      n_lmP_loc = dist_n_lmP(coord_m)
      
      n_lmMag_loc = 1
      n_lmChe_loc = 1
      n_lmTP_loc  = 1
      n_lmDC_loc  = 1
      if (l_mag          ) n_lmMag_loc = n_lm_loc
      if (l_chemical_conv) n_lmChe_loc = n_lm_loc
      if (l_TP_form      ) n_lmTP_loc  = n_lm_loc
      if (l_double_curl  ) n_lmDC_loc  = n_lm_loc
      
   end subroutine distribute_lm
   !----------------------------------------------------------------------------
   subroutine distribute_mlo
      !   
      !   Distributes the l's and the m's from the ML-space. Every r point is 
      !   local.
      !   
      !   This function will keep the m's distribution untouched. Only the l's
      !   will be shuffled around. In this framework, we will always have:
      !   
      !   coord_m [m in (l,m,r) coordinates] = coord_mo [m in (r,m,l) coordinates]
      !   
      !   1) Splits n_lm(coord_m=coord_mo) amongst n_rank_r = n_rank_lo ranks.
      !   
      !   Author: Rafael Lago, MPCDF, June 2018
      !   
      integer :: tmp(0:n_ranks_r-1,0:2)
      integer :: icoord_mlo, icoord_mo, icoord_lo
      integer :: m_idx, l_idx, mlo_idx, irank
      integer :: l, m
      
      allocate(dist_n_mlo(0:n_ranks-1))
      dist_n_mlo = 0
      
      !-- Compute how many ml-pairs will be store in each rank
      !
      do icoord_mo=0,n_ranks_m-1
         tmp = 0
         call distribute_contiguous_last(tmp, dist_n_lm(icoord_mo), n_ranks_lo)
         
         !-- We have split all the n_lm poitns of coord_m=coord_mo into
         !   n_rank_lo parts. Now we just need to copy this amount into each
         !   coord_lo
         do icoord_lo=0,n_ranks_lo-1
            icoord_mlo = mlo2rank(icoord_mo, icoord_lo)
            dist_n_mlo(icoord_mlo) = tmp(icoord_lo,2) - tmp(icoord_lo,1) + 1
         end do
      end do
      
      !-- Assign the (m,l) pairs to each rank, according to the count of 
      !   ml-pairs in dist_n_mlo
      n_mlo_array = maxval(dist_n_mlo)
      allocate(dist_mlo(0:n_ranks-1, n_mlo_array, 2))
      call distribute_mlo_mfirst(dist_mlo, dist_n_mlo)
      
  
      !-- Count how many different l's this rank has
      n_lo_loc = 0
      do l=0,l_max
         if (any(dist_mlo(coord_mlo,:,2)==l)) n_lo_loc = n_lo_loc + 1
      end do
      
      !-- Count how many different m's this rank has
      n_mo_loc = 0
      do m=0,l_max
         if (any(dist_mlo(coord_mlo,:,1)==m)) n_mo_loc = n_mo_loc + 1
      end do
      
      !-- Count how many (m,l) pairs this rank has (in case it differs from 
      !   the original estimation of the dist_n_mlo variable)
      dist_n_mlo = count(dist_mlo(:,:,1)>=0, dim=2)
      
      if (sum(dist_n_mlo) /= lm_max) then
         print *, "Something went wrong while distributing mlo. Aborting!"
         print *, "sum(dist_n_mlo) = ", sum(dist_n_mlo), ", lm_max=", lm_max
         stop
      end if
      
      n_mlo_loc = dist_n_mlo(coord_mlo)
      mlo_max = lm_max
      
   end subroutine distribute_mlo
   
   !----------------------------------------------------------------------------   
   subroutine distribute_mlo_mfirst(mlo,n_mlo)
      !
      !   This loop will now distribute the (m,l) pairs amongst all the 
      !   rank_mlo. It will make sure that each coord_mo will only keep the 
      !   (m,l) pairs whose m is in coord_m. This is aimed at reducing 
      !   communication. It will also follow the number of (m,l) points 
      !   that we saved in n_mlo input variable.
      !   
      !   This subroutine will minimize the number of l's in each rank by 
      !   looping over m first, and then over l while distributing the pairs.
      !   
      !   This distribution is far from being optimal and should work just as 
      !   a placeholder.
      !   
      !   This will place l as the slowest index and m as the fastest!
      !   
      !   Author: Rafael Lago, MPCDF, June 2018
      !
      integer, intent(in)    :: n_mlo(0:n_ranks-1)
      integer, intent(inout) :: mlo(0:n_ranks-1, n_mlo_array, 2)
      integer :: icoord_mo, icoord_lo, icoord_mlo
      integer :: l, m, m_idx, mlo_idx
      integer :: taken(0:m_max, 0:l_max)
      
      
      taken = -1
      do m=0,l_max
         taken(m,m:l_max) = (/m:l_max/)
      end do
      
      mlo = -1
      
      do icoord_mo=0,n_ranks_mo-1
         
         l = 0
         m_idx = 1
         do icoord_lo=0,n_ranks_lo-1
            icoord_mlo = mlo2rank(icoord_mo, icoord_lo)
            
            mlo_idx = 1
            do while (mlo_idx<=n_mlo(icoord_mlo))
               if (m_idx>dist_m(icoord_mo,0)) then
                  m_idx = 1
                  l = l + 1
               end if
               
               m = dist_m(icoord_mo, m_idx)
               
               if (l<m) then
                  m_idx = m_idx + 1
                  cycle
               end if
               
               mlo(icoord_mlo, mlo_idx, 1) = m
               mlo(icoord_mlo, mlo_idx, 2) = l
               mlo_idx = mlo_idx + 1
               m_idx = m_idx + 1
            end do
            
         end do
      end do
      
   end subroutine distribute_mlo_mfirst
   
   !----------------------------------------------------------------------------   
   subroutine distribute_mlo_lfirst(mlo,n_mlo)
      !
      !   This loop will now distribute the (m,l) pairs amongst all the 
      !   rank_mlo. It will make sure that each coord_mo will only keep the 
      !   (m,l) pairs whose m is in coord_m. This is aimed at reducing 
      !   communication. It will also follow the number of (m,l) points 
      !   that we saved in n_mlo input variable.
      !   
      !   This subroutine will minimize the number of m's in each rank by 
      !   looping over l first, and then over m while distributing the pairs.
      !   
      !   This is probably not what you want. This subroutine is here mostly
      !   for academic purposes and tests!
      !
      !   Author: Rafael Lago, MPCDF, June 2018
      !
      integer, intent(in)    :: n_mlo(0:n_ranks-1)
      integer, intent(inout) :: mlo(0:n_ranks-1, n_mlo_array, 2)
      integer :: icoord_mo, icoord_lo, icoord_mlo
      integer :: l, m, m_idx, mlo_idx
      
      mlo = -1
      do icoord_mo=0,n_ranks_mo-1
         m_idx = 1
         m = dist_m(icoord_mo, 1)
         l = m-1
         
         do icoord_lo=0,n_ranks_lo-1
            icoord_mlo = mlo2rank(icoord_mo, icoord_lo)
            
            do mlo_idx=1,n_mlo(icoord_mlo)
               l = l + 1
               if (l>l_max) then
                  m_idx = m_idx + 1
                  m = dist_m(icoord_mo, m_idx)
                  l = m
               end if
               mlo(icoord_mlo, mlo_idx, 1) = m
               mlo(icoord_mlo, mlo_idx, 2) = l
            end do
         end do
      end do
   end subroutine distribute_mlo_lfirst

   !----------------------------------------------------------------------------
   subroutine check_geometry
      !
      !  This function checks truncations and writes it into STDOUT and the 
      !  log-file.                                 
      !  

      if ( minc < 1 ) then
         call abortRun('! Wave number minc should be > 0!')
      end if
      if ( mod(n_phi_tot,minc) /= 0 .and. (.not. l_axi) ) then
         call abortRun('! Number of longitude grid points n_phi_tot must be a multiple of minc')
      end if
      if ( mod(n_phi_max,4) /= 0 .and. (.not. l_axi) ) then
         call abortRun('! Number of longitude grid points n_phi_tot/minc must be a multiple of 4')
      end if
      if ( mod(n_phi_tot,16) /= 0 .and. (.not. l_axi) ) then
         call abortRun('! Number of longitude grid points n_phi_tot must be a multiple of 16')
      end if
      if ( n_phi_max/2 <= 2 .and. (.not. l_axi) ) then
         call abortRun('! Number of longitude grid points n_phi_tot must be larger than 2*minc')
      end if

      !-- Checking radial grid:
      if ( .not. l_finite_diff ) then
         if ( mod(n_r_max-1,4) /= 0 ) then
            call abortRun('! Number n_r_max-1 should be a multiple of 4')
         end if
      end if

      if ( n_theta_max <= 2 ) then
         call abortRun('! Number of latitude grid points n_theta_max must be larger than 2')
      end if
      if ( mod(n_theta_max,4) /= 0 ) then
         call abortRun('! Number n_theta_max of latitude grid points be a multiple must be a multiple of 4')
      end if
      if ( n_cheb_max > n_r_max ) then
         call abortRun('! n_cheb_max should be <= n_r_max!')
      end if
      if ( n_cheb_max < 1 ) then
         call abortRun('! n_cheb_max should be > 1!')
      end if
      if ( (n_phi_max+1)*n_theta_max > lm_max_real*(n_r_max+2) ) then
         call abortRun('! (n_phi_max+1)*n_theta_max > lm_max_real*(n_r_max+2) !')
      end if

   end subroutine check_geometry
   !----------------------------------------------------------------------------   
   subroutine distribute_discontiguous_snake(dist, max_len, N, p)
      !  
      !   Distributes a list of points [x1, x2, ..., xN] amonst p ranks using
      !   snake ordering. The output is just a list containing the indexes
      !   of these points (e.g. [0,7,8,15]).
      !  
      !   max_len is supposed to be the ceiling(N/p)
      !  
      !   Author: Rafael Lago, MPCDF, June 2018
      !  
      integer, intent(in)    :: max_len, N, p
      integer, intent(inout) :: dist(0:p-1, 0:max_len)
      
      integer :: j, ipt, irow
      
      dist(:,:) =  -1
      ipt  = 1
      irow = 1
      
      do while (.TRUE.)
         do j=0, p-1
            dist(j, irow) = ipt
            ipt = ipt + 1
            if (ipt > N) return
         end do
         irow = irow + 1
         do j=p-1,0,-1
            dist(j, irow) = ipt
            ipt = ipt + 1
            if (ipt > N) return
         end do
         irow = irow + 1
      end do
   end subroutine distribute_discontiguous_snake
   !----------------------------------------------------------------------------   
   subroutine distribute_discontiguous_roundrobin(dist, max_len, N, p)
      !  
      !   Distributes a list of points [x1, x2, ..., xN] amonst p ranks using
      !   round robin ordering. The output is just a list containing the indexes
      !   of these points (e.g. [0,4,8,12]).
      !  
      !   max_len is supposed to be the ceiling(N/p)
      !  
      !   Author: Rafael Lago, MPCDF, June 2018
      !  
      integer, intent(in)    :: max_len, N, p
      integer, intent(inout) :: dist(0:p-1, 0:max_len)
      
      integer :: j, ipt, irow
      
      dist(:,:) =  -1
      ipt  = 1
      irow = 1
      
      do while (.TRUE.)
         do j=0, p-1
            dist(j, irow) = ipt
            ipt = ipt + 1
            if (ipt > N) return
         end do
         irow = irow + 1
      end do
   end subroutine distribute_discontiguous_roundrobin
   
   !----------------------------------------------------------------------------
   subroutine distribute_contiguous_first(dist,N,p)
      !  
      !   Distributes a list of points [x1, x2, ..., xN] amonst p ranks such 
      !   that each rank receives a "chunk" of points. The output are three 
      !   integers (per rank) referring to the number of points, the first 
      !   points and the last point of the chunk (e.g. [4,0,3]).
      !  
      !   If the number of points is not divisible by p, we add one extra point
      !   in the first N-(N/p) ranks (thus, "first")
      !  
      !   Author: Rafael Lago, MPCDF, June 2018
      !  
      integer, intent(in) :: p
      integer, intent(in) :: N
      integer, intent(out) :: dist(0:p-1,0:2)
      
      integer :: rem, loc, i
      
      loc = N/p
      rem = N - loc*p
      do i=0,p-1
         dist(i,1) = loc*i + min(i,rem) + 1
         dist(i,2) = loc*(i+1) + min(i+1,rem)
      end do
   end subroutine distribute_contiguous_first
   !----------------------------------------------------------------------------
   subroutine distribute_contiguous_last(dist,N,p)
      !  
      !   Like distribute_contiguous_first, but extra points go into the 
      !   last N-(N/p) ranks (thus, "last")
      !  
      !   Author: Rafael Lago, MPCDF, June 2018
      !  
      integer, intent(in) :: p
      integer, intent(in) :: N
      integer, intent(out) :: dist(0:p-1,0:2)
      
      integer :: rem, loc, i
      
      loc = N/p
      rem = N - loc*p
      do i=0,p-1
         dist(i,1) = loc*i + max(i+rem-p,0) + 1
         dist(i,2) = loc*(i+1) + max(i+rem+1-p,0)
      end do
   end subroutine distribute_contiguous_last
   
   !----------------------------------------------------------------------------
   subroutine print_contiguous_distribution(dist,p,name)
      !  
      !   Author: Rafael Lago, MPCDF, June 2018
      !  
      integer, intent(in) :: p
      integer, intent(in) :: dist(0:p-1,0:2)
      character(*), intent(in) :: name
      integer :: i
      
      if (rank /= 0) return
      
      print "(' !  Partition in rank_',A,' ', I0, ': ', I0,'-',I0, '  (', I0, ' pts)')", name, &
            0, dist(0,1), dist(0,2), dist(0,0)
            
      do i=1, p-1
         print "(' !               rank_',A,' ', I0, ': ', I0,'-',I0, '  (', I0, ' pts)')", name, &
               i, dist(i,1), dist(i,2), dist(i,0)
      end do
   end subroutine print_contiguous_distribution
   
   !----------------------------------------------------------------------------
   subroutine print_discontiguous_distribution(dist,max_len,p,name)
      !  
      !   Author: Rafael Lago, MPCDF, June 2018
      !  
      integer, intent(in) :: max_len, p
      integer, intent(in) :: dist(0:p-1,0:max_len)
      character(*), intent(in) :: name
      
      integer :: i, j, counter
      
      if (rank /= 0) return
      
      write (*,'(A,I0,A,I0)', ADVANCE='NO') ' !  Partition in rank_'//name//' ', 0, ' :', dist(0,1)
      counter = 1
      do j=2, dist(0,0)
         write (*, '(A,I0)', ADVANCE='NO') ',', dist(0,j)
      end do
      write (*, '(A,I0,A)') "  (",dist(0,0)," pts)"
      
      do i=1, n_ranks_theta-1
         write (*,'(A,I0,A,I0)', ADVANCE='NO') ' !               rank_'//name//' ', i, ' :', dist(i,1)
         counter = 1
         do j=2, dist(i,0)
            write (*, '(A,I0)', ADVANCE='NO') ',', dist(i,j)
         end do
         write (*, '(A,I0,A)') "  (",dist(i,0)," pts)"
      end do
   end subroutine print_discontiguous_distribution
   
   !----------------------------------------------------------------------------
   subroutine print_mlo_distribution
      !   
      !   Because this is a very special kind of distribution, it has its own
      !   print routine
      !   
      !   Author: Rafael Lago, MPCDF, June 2018
      !
      integer :: icoord_mlo, mlo_idx
      integer :: l, m
      logical :: lfirst
      
      if (rank/=0) return
      
      do icoord_mlo=0,n_ranks-1
         write (*,'(A,I0,A)') ' !  Distribution rank_mlo ',icoord_mlo,' :'

         do m=0,m_max
            if (.not. any(dist_mlo(icoord_mlo,:,1)==m)) cycle
            write (*,'(A,I0,A)', ADVANCE='NO') ' !                            m=',m,', l=['
            lfirst = .true.
            do mlo_idx=1,dist_n_mlo(icoord_mlo)
               if (dist_mlo(icoord_mlo,mlo_idx,1)/=m) cycle
               l = dist_mlo(icoord_mlo,mlo_idx,2)
               if (lfirst) then
                  write (*,'(I0)', ADVANCE='NO') l
                  lfirst = .false.
               else
                  write (*,'(A,I0)', ADVANCE='NO') ',',l
               end if
            end do
            write (*,'(A)', ADVANCE='NO') "]"//NEW_LINE("a")
         end do
      end do
      
   end subroutine print_mlo_distribution
   
   !----------------------------------------------------------------------------
   subroutine print_mlo_distribution_summary
      !   
      !   Summarized version of print_mlo_distribution
      !   
      !   Author: Rafael Lago, MPCDF, June 2018
      !
      integer :: icoord_mlo, m_count, l_count
      integer :: l, m
      
      if (rank/=0) return
      
      do icoord_mlo=0,n_ranks-1
         if (icoord_mlo==0) write (*,'(A,I0,A)', ADVANCE='NO') ' !   # points in rank_mlo ',icoord_mlo,' :'
         if (icoord_mlo/=0) write (*,'(A,I0,A)', ADVANCE='NO') ' !               rank_mlo ',icoord_mlo,' :'
         
         !-- Count how many different l's
         l_count = 0
         do l=0,l_max
            if (any(dist_mlo(icoord_mlo,:,2)==l)) l_count = l_count + 1
         end do
         
         !-- Count how many different m's
         m_count = 0
         do m=0,l_max
            if (any(dist_mlo(icoord_mlo,:,1)==m)) m_count = m_count + 1
         end do
         
         write (*,'(I0,A,I0,A,I0,A)') m_count, " m, ", l_count, " l (", dist_n_mlo(icoord_mlo), " total)"
      end do
      
   end subroutine print_mlo_distribution_summary
   
end module geometry

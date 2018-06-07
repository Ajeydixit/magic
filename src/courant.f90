module courant_mod
 
   use parallel_mod
   use precision_mod
   use geometry, only: nrp, n_phi_max, n_theta_beg, n_theta_end, &
       &                 comm_theta, l_r, u_r
   use radial_functions, only: orho1, orho2, or4, or2
   use physical_parameters, only: LFfac, opm
   use num_param, only: courfac, delxr2, delxh2, alffac
   use blocking, only: nfs
   use horizontal_data, only: osn2
   use logic, only: l_mag, l_mag_LF, l_mag_kin, l_cour_alf_damp
   use useful, only: logWrite
   use constants, only: half, one, two

   implicit none

   private

   public :: courant, dt_courant

contains

   subroutine courant(n_r,dtrkc,dthkc,vr,vt,vp,br,bt,bp)
      !
      !  courant condition check: calculates Courant                      
      !  advection lengths in radial direction dtrkc                      
      !  and in horizontal direction dthkc                                
      !  on the local radial level n_r                                   
      !                                                                   
      !  for the effective velocity, the abs. sum of fluid                
      !  velocity and Alfven velocity is taken                            
      !                                                                   
      !  instead of the full Alfven velocity                              
      !  a modified Alfven velocity is employed that takes                
      !  viscous and Joule damping into account. Different               
      !  Courant factors are used for the fluid velocity and              
      !  the such modified Alfven velocity                                
      !                                                                   
      !
    
      !-- Input variable:
      integer,  intent(in) :: n_r           ! radial level
      real(cp), intent(in) :: vr(n_phi_max,n_theta_beg:n_theta_end)   ! radial velocity
      real(cp), intent(in) :: vt(n_phi_max,n_theta_beg:n_theta_end)   ! longitudinal velocity
      real(cp), intent(in) :: vp(n_phi_max,n_theta_beg:n_theta_end)   ! azimuthal velocity
      real(cp), intent(in) :: br(n_phi_max,n_theta_beg:n_theta_end)   ! radial magnetic field
      real(cp), intent(in) :: bt(n_phi_max,n_theta_beg:n_theta_end)   ! longitudinal magnetic field
      real(cp), intent(in) :: bp(n_phi_max,n_theta_beg:n_theta_end)   ! azimuthal magnetic field
    
      !-- Output:
      real(cp), intent(inout) :: dtrkc    ! Courant step (based on radial advection)
                                          ! for the range of points covered
      real(cp), intent(inout) :: dthkc    ! Courant step based on horizontal advection
    
      !-- Local  variables:
      integer :: n_theta       ! absolut no of theta
      integer :: n_theta_nhs   ! no of theta in NHS
      integer :: n_phi         ! no of longitude
    
      real(cp) :: valri2,valhi2,valh2,valh2m
      real(cp) :: vr2max,vh2max
      real(cp) :: valr,valr2,vflr2,vflh2
      real(cp) :: O_r_E_2,O_r_E_4
      real(cp) :: cf2,af2
    
      if ( l_cour_alf_damp ) then
         valri2=(half*(one+opm))**2/delxr2(n_r)
         valhi2=(half*(one+opm))**2/delxh2(n_r)
      else
         valri2=0.0_cp
         valhi2=0.0_cp
      end if
    
      vr2max=0.0_cp
      vh2max=0.0_cp
      cf2=courfac*courfac
      O_r_E_4=or4(n_r)
      O_r_E_2=or2(n_r)
    
    
      if ( l_mag .and. l_mag_LF .and. .not. l_mag_kin ) then
    
         af2=alffac*alffac
    
         do n_theta=n_theta_beg,n_theta_end
            n_theta_nhs=(n_theta+1)/2 ! northern hemisphere=odd n_theta
    
            do n_phi=1,n_phi_max
    
               vflr2=orho2(n_r)*vr(n_phi,n_theta)*vr(n_phi,n_theta)
               valr =br(n_phi,n_theta)*br(n_phi,n_theta) * &
                     LFfac*orho1(n_r)
               valr2=valr*valr/(valr+valri2)
               vr2max=max(vr2max,O_r_e_4*(cf2*vflr2+af2*valr2))
    
               vflh2= ( vt(n_phi,n_theta)*vt(n_phi,n_theta) +  &
                        vp(n_phi,n_theta)*vp(n_phi,n_theta) )* &
                        osn2(n_theta_nhs)*orho2(n_r)
               valh2= ( bt(n_phi,n_theta)*bt(n_phi,n_theta) +  &
                        bp(n_phi,n_theta)*bp(n_phi,n_theta) )* &
                        LFfac*osn2(n_theta_nhs)*orho1(n_r)
               valh2m=valh2*valh2/(valh2+valhi2)
               vh2max=max(vh2max,O_r_E_2*(cf2*vflh2+af2*valh2m))
    
            end do
    
         end do
    
      else   ! Magnetic field ?
    
         do n_theta=n_theta_beg,n_theta_end
            n_theta_nhs=(n_theta+1)/2 ! northern hemisphere=odd n_theta
    
            do n_phi=1,n_phi_max
    
               vflr2=orho2(n_r)*vr(n_phi,n_theta)*vr(n_phi,n_theta)
               vr2max=max(vr2max,cf2*O_r_E_4*vflr2)
    
               vflh2= ( vt(n_phi,n_theta)*vt(n_phi,n_theta) + &
                        vp(n_phi,n_theta)*vp(n_phi,n_theta) )* &
                        osn2(n_theta_nhs)*orho2(n_r)
               vh2max=max(vh2max,cf2*O_r_E_2*vflh2)
    
            end do
    
         end do
    
      end if   ! Magnetic field ?
    
      if ( vr2max /= 0.0_cp ) dtrkc=min(dtrkc,sqrt(delxr2(n_r)/vr2max))
      if ( vh2max /= 0.0_cp ) dthkc=min(dthkc,sqrt(delxh2(n_r)/vh2max))
    
   end subroutine courant
!------------------------------------------------------------------------------
   subroutine dt_courant(dt_r,dt_h,l_new_dt,dt,dt_new,dtMax,dtrkc,dthkc)
      !
      !     Check if Courant criterion based on combined
      !     fluid and Alfven velocity is satisfied
      !     Returns new value of time step dtnew
      !
      !     dtr,dth: (output) radial/horizontal Courant time step
      !     n_time_step: (input) time step number
      !     l_new_dt: (output) flag indicating that time step is changed (=1) or not (=0)
      !     dt: (input) old time step
      !     dtnew: (output) new time step
      !     dtMin: (input) lower limit for time step (termination if dtnew < dtMin)
      !     dtMax: (input) upper limit for time step
      !     dtrkc: (input) radial Courant time step as function of radial level
      !     dthkc: (input) horizontal Courant time step as function of radial level
      !

      !-- Input variables:
      real(cp), intent(in) :: dt
      real(cp), intent(in) :: dtMax
      real(cp), intent(in) :: dtrkc(l_r:u_r),dthkc(l_r:u_r)
    
      !-- Output variables:
      logical,  intent(out) :: l_new_dt
      real(cp), intent(out) :: dt_new
      real(cp), intent(out) :: dt_r,dt_h
    
      !-- Local:
      integer :: n_r
      real(cp) :: dt_rh,dt_2
      real(cp) :: dt_fac
    
      character(len=200) :: message
    
    
      dt_fac=two
      dt_r  =1000.0_cp*dtMax
      dt_h  =dt_r
      do n_r=l_r,u_r
         dt_r=min(dtrkc(n_r),dt_r)
         dt_h=min(dthkc(n_r),dt_h)
      end do
      
#ifdef WITH_MPI
      call MPI_Allreduce(MPI_IN_PLACE,dt_r,1,MPI_DEF_REAL,MPI_MIN,comm_gs,ierr)
      call MPI_Allreduce(MPI_IN_PLACE,dt_h,1,MPI_DEF_REAL,MPI_MIN,comm_gs,ierr)
#endif
    
      dt_rh=min(dt_r,dt_h)
      dt_2 =min(half*(one/dt_fac+one)*dt_rh,dtMax)
      
      if ( dt > dtMax ) then
    
         l_new_dt=.true.
         dt_new=dtMax
         write(message,'(1P," ! COURANT: dt=dtMax =",ES12.4,A)') dtMax,&
              &" ! Think about changing dtMax !"
         call logWrite(message)
    
      else if ( dt > dt_rh ) then
    
         l_new_dt=.true.
         dt_new  =dt_2
         write(message,'(1P," ! COURANT: dt=",ES11.4," > dt_r=",ES12.4, &
              &       " and dt_h=",ES12.4)') dt,dt_r,dt_h
         call logWrite(message)
    
      else if ( dt_fac*dt < dt_rh .and. dt < dtMax ) then
    
         l_new_dt=.true.
         dt_new=dt_2
         write(message,'(" ! COURANT: ",F4.1,1P,"*dt=",ES11.4, &
              &     " < dt_r=",ES12.4," and dt_h=",ES12.4)') &
              &     dt_fac,dt_fac*dt,dt_r,dt_h
         call logWrite(message)
    
      end if
    
      if ( dt == dt_new ) l_new_dt= .false. 
       
   end subroutine dt_courant
!-----------------------------------------------------------------------
end module courant_mod

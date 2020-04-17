module nl_special_calc
   !
   ! This module allows to calculcate several diagnostics that need to be
   ! computed in the physical space (non-linear quantities)
   !

   use precision_mod
   use truncation, only: nrp, n_phi_max, l_max, l_maxMag, n_r_icb, &
       &                 n_r_cmb, nThetaStart, nThetaStop, n_theta_loc
   use constants, only: pi, one, two, third, half
   use logic, only: l_mag_nl, l_anelastic_liquid
   use physical_parameters, only: ek, ViscHeatFac, ThExpNb
   use radial_functions, only: orho1, orho2, or2, or1, beta, temp0, &
       &                       visc, or4, r, alpha0
   use horizontal_data, only: O_sin_theta_E2, cosTheta, sn2, osn2, cosn2
#ifdef WITH_SHTNS
   use shtns, only: spat_to_SH_axi_dist
#else
   use legendre_grid_to_spec, only: legTFAS, legTFAS2
#endif

   implicit none

   private

   public :: get_nlBLayers, get_perpPar, get_fluxes, get_helicity, &
   &         get_visc_heat

contains

   subroutine get_nlBLayers(vt,vp,dvtdr,dvpdr,dsdr,dsdt,dsdp,uhLMr,duhLMr, &
              &             gradsLMr,nR)
      !
      !   Calculates axisymmetric contributions of:
      !
      !     * the horizontal velocity :math:`u_h = \sqrt{u_\theta^2+u_\phi^2}`
      !     * its radial derivative :math:`|\partial u_h/\partial r|`
      !     * The thermal dissipation rate :math:`(\nabla T)^2`
      !
      !   This subroutine is used when one wants to evaluate viscous and thermal
      !   dissipation layers
      !

      !-- Input of variables
      integer,  intent(in) :: nR
      real(cp), intent(in) :: vt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: vp(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvtdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvpdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dsdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dsdt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dsdp(nrp,nThetaStart:nThetaStop)

      !-- Output variables:
      real(cp), intent(out) :: uhLMr(l_max+1)
      real(cp), intent(out) :: duhLMr(l_max+1)
      real(cp), intent(out) :: gradsLMr(l_max+1)

      !-- Local variables:
      integer :: nTheta
      integer :: nPhi
      real(cp) :: uh, duh, phiNorm, grads
      real(cp) :: uhAS(nThetaStart:nThetaStop), duhAS(nThetaStart:nThetaStop)
      real(cp) :: gradsAS(nThetaStart:nThetaStop)

      phiNorm=one/real(n_phi_max,cp)

      !--- Horizontal velocity uh and duh/dr + (grad T)**2
#ifdef WITH_SHTNS
      !$omp parallel do default(shared)                     &
      !$omp& private(nTheta, nPhi, uh, duh, grads)
#endif
      do nTheta=nThetaStart,nThetaStop
         uhAS(nTheta)   =0.0_cp
         duhAS(nTheta)  =0.0_cp
         gradsAS(nTheta)=0.0_cp
         do nPhi=1,n_phi_max
            uh=or2(nR)*orho2(nR)*O_sin_theta_E2(nTheta)*(   &
            &             vt(nPhi,nTheta)*vt(nPhi,nTheta)+  &
            &             vp(nPhi,nTheta)*vp(nPhi,nTheta)  )
            duh=or2(nR)*orho2(nR)*O_sin_theta_E2(nTheta)*(            &
            &                    dvtdr(nPhi,nTheta)*vt(nPhi,nTheta)-  &
            &    (or1(nR)+beta(nR))*vt(nPhi,nTheta)*vt(nPhi,nTheta)+  &
            &                    dvpdr(nPhi,nTheta)*vp(nPhi,nTheta)-  &
            &    (or1(nR)+beta(nR))*vp(nPhi,nTheta)*vp(nPhi,nTheta) )

            grads =  dsdr(nPhi,nTheta)*dsdr(nPhi,nTheta)          &
            &      +or2(nR)*O_sin_theta_E2(nTheta)*(              &
            &              dsdt(nPhi,nTheta)*dsdt(nPhi,nTheta)    &
            &             +dsdp(nPhi,nTheta)*dsdp(nPhi,nTheta) )

            uhAS(nTheta)=uhAS(nTheta)+sqrt(uh)
            if (uh /= 0.0_cp) duhAS(nTheta)=duhAS(nTheta)+abs(duh)/sqrt(uh)
            gradsAS(nTheta)=gradsAS(nTheta)+grads
         end do
         uhAS(nTheta)   =phiNorm*uhAS(nTheta)
         duhAS(nTheta)  =phiNorm*duhAS(nTheta)
         gradsAS(nTheta)=phiNorm*gradsAS(nTheta)
      end do
#ifdef WITH_SHTNS
      !$omp end parallel do
#endif

      !------ Add contribution from thetas in block:
#ifdef WITH_SHTNS
      call spat_to_SH_axi_dist(gradsAS,gradsLMr)
      call spat_to_SH_axi_dist(uhAS,uhLMr)
      call spat_to_SH_axi_dist(duhAS,duhLMr)
#else
      call legTFAS2(uhLMr,duhLMr,uhAS,duhAS,l_max+1,nThetaStart,n_theta_loc)
      call legTFAS(gradsLMr,gradsAS,l_max+1,nThetaStart,n_theta_loc)
#endif

   end subroutine get_nlBLayers
!------------------------------------------------------------------------------
   subroutine get_perpPar(vr,vt,vp,EperpLMr,EparLMr,EperpaxiLMr,EparaxiLMr,nR)
      !
      !   Calculates the energies parallel and perpendicular to the rotation axis
      !
      !     * :math:`E_\perp = 0.5 (v_s^2+v_\phi^2)` with
      !       :math:`v_s= v_r\sin\theta+v_\theta\cos\theta`
      !     * :math:`E_\parallel  = 0.5v_z^2` with
      !       :math:`v_z= v_r\cos\theta-v_\theta*\sin\theta`
      !

      !-- Input of variables
      integer,  intent(in) :: nR
      real(cp), intent(in) :: vr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: vt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: vp(nrp,nThetaStart:nThetaStop)

      !-- Output variables:
      real(cp), intent(out) :: EperpLMr(l_max+1),EparLMr(l_max+1)
      real(cp), intent(out) :: EperpaxiLMr(l_max+1),EparaxiLMr(l_max+1)

      !-- Local variables:
      integer :: nTheta,nThetaNHS
      integer :: nPhi
      real(cp) :: vras,vtas,vpas,phiNorm,Eperp,Epar,Eperpaxi,Eparaxi
      real(cp) :: EperpAS(nThetaStart:nThetaStop),EparAS(nThetaStart:nThetaStop)
      real(cp) :: EperpaxiAS(nThetaStart:nThetaStop),EparaxiAS(nThetaStart:nThetaStop)

      phiNorm=one/real(n_phi_max,cp)

#ifdef WITH_SHTNS
      !$omp parallel do default(shared)                             &
      !$omp& private(nTheta, nPhi, Eperp, Epar, Eperpaxi, Eparaxi)  &
      !$omp& private(vras, vtas, vpas, nThetaNHS)
#endif
      do nTheta=nThetaStart,nThetaStop
         nThetaNHS=(nTheta+1)/2

         EperpAS(nTheta)   =0.0_cp
         EparAS(nTheta)    =0.0_cp
         EperpaxiAS(nTheta)=0.0_cp
         EparaxiAS(nTheta) =0.0_cp
         Eperp   =0.0_cp
         Epar    =0.0_cp
         Eperpaxi=0.0_cp
         Eparaxi =0.0_cp
         vras    =0.0_cp
         vtas    =0.0_cp
         vpas    =0.0_cp

         do nPhi=1,n_phi_max
            vras=vras+vr(nPhi,nTheta)
            vtas=vtas+vt(nPhi,nTheta)
            vpas=vpas+vp(nPhi,nTheta)
         end do
         vras=vras*phiNorm
         vtas=vtas*phiNorm
         vpas=vpas*phiNorm

         do nPhi=1,n_phi_max
            Eperp=half*or2(nR)*orho2(nR)*(                                         &
            &       or2(nR)*sn2(nThetaNHS)*      vr(nPhi,nTheta)*vr(nPhi,nTheta) + &
            &       (osn2(nThetaNHS)-one)*       vt(nPhi,nTheta)*vt(nPhi,nTheta) + &
            &       two*or1(nR)*cosTheta(nTheta)*vr(nPhi,nTheta)*vt(nPhi,nTheta) + &
            &       osn2(nThetaNHS)*             vp(nPhi,nTheta)*vp(nPhi,nTheta) )

            Epar =half*or2(nR)*orho2(nR)*(                                         &
            &       or2(nR)*(one-sn2(nThetaNHS))*vr(nPhi,nTheta)*vr(nPhi,nTheta) + &
            &                                    vt(nPhi,nTheta)*vt(nPhi,nTheta) - &
            &       two*or1(nR)*cosTheta(nTheta)*vr(nPhi,nTheta)*vt(nPhi,nTheta) )

            Eperpaxi=half*or2(nR)*orho2(nR)*(                  &
            &         or2(nR)*sn2(nThetaNHS)*      vras*vras + &
            &         (osn2(nThetaNHS)-one)*       vtas*vtas + &
            &         two*or1(nR)*cosTheta(nTheta)*vras*vtas + &
            &         osn2(nThetaNHS)*             vpas*vpas )

            Eparaxi =half*or2(nR)*orho2(nR)*(                  &
            &         or2(nR)*(one-sn2(nThetaNHS))*vras*vras + &
            &                                      vtas*vtas - &
            &         two*or1(nR)*cosTheta(nTheta)*vras*vtas )

            EperpAS(nTheta)   =   EperpAS(nTheta)+Eperp
            EparAS(nTheta)    =    EparAS(nTheta)+Epar
            EperpaxiAS(nTheta)=EperpaxiAS(nTheta)+Eperpaxi
            EparaxiAS(nTheta) = EparaxiAS(nTheta)+Eparaxi
         end do
         EperpAS(nTheta)   =phiNorm*   EperpAS(nTheta)
         EparAS(nTheta)    =phiNorm*    EparAS(nTheta)
         EperpaxiAS(nTheta)=phiNorm*EperpaxiAS(nTheta)
         EparaxiAS(nTheta) =phiNorm* EparaxiAS(nTheta)
      end do
#ifdef WITH_SHTNS
      !$omp end parallel do
#endif

      !-- Add contribution from thetas in block:
#ifdef WITH_SHTNS
      call spat_to_SH_axi_dist(EperpAS, EperpLMr)
      call spat_to_SH_axi_dist(EparAS, EparLMr)
      call spat_to_SH_axi_dist(EperpaxiAS, EperpaxiLMr)
      call spat_to_SH_axi_dist(EparaxiAS, EparaxiLMr)
#else
      call legTFAS2(EperpLMr,EparLMr,EperpAS,EparAS,l_max+1,nThetaStart,n_theta_loc)
      call legTFAS2(EperpaxiLMr,EparaxiLMr,EperpaxiAS,EparaxiAS,l_max+1, &
           &        nThetaStart,n_theta_loc)
#endif

   end subroutine get_perpPar
!------------------------------------------------------------------------------
   subroutine get_fluxes(vr,vt,vp,dvrdr,dvtdr,dvpdr,dvrdt,dvrdp,sr,pr,br,bt,bp, &
              &          cbt,cbp,fconvLMr,fkinLMr,fviscLMr,fpoynLMr,fresLMR,nR)
      !
      !   Calculates the fluxes:
      !
      !     * Convective flux: :math:`F_c= \rho T (u_r s)`
      !     * Kinetic flux: :math:`F_k = 1/2\,\rho u_r (u_r^2+u_\theta^2+u_\phi^2)`
      !     * Viscous flux: :math:`F_= -(u \cdot S )_r`)
      !
      !   If the run is magnetic, then this routine also computes:
      !
      !     * Poynting flux
      !     * resistive flux
      !

      !-- Input of variables
      integer,  intent(in) :: nR
      real(cp), intent(in) :: vr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: vt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: vp(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvrdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvtdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvpdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvrdt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvrdp(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: sr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: pr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: br(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: bt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: bp(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: cbt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: cbp(nrp,nThetaStart:nThetaStop)

      !-- Output variables:
      real(cp), intent(out) :: fkinLMr(l_max+1)
      real(cp), intent(out) :: fconvLMr(l_max+1)
      real(cp), intent(out) :: fviscLMr(l_max+1)
      real(cp), intent(out) :: fresLMr(l_maxMag+1),fpoynLMr(l_maxMag+1)

      !-- Local variables:
      integer :: nTheta,nThetaNHS
      integer :: nPhi
      real(cp) :: fkin, fconv, phiNorm, fvisc, fpoyn, fres
      real(cp) :: fkinAS(nThetaStart:nThetaStop),fconvAS(nThetaStart:nThetaStop)
      real(cp) :: fviscAS(nThetaStart:nThetaStop)
      real(cp) :: fpoynAS(nThetaStart:nThetaStop),fresAS(nThetaStart:nThetaStop)

      phiNorm=two*pi/real(n_phi_max,cp)

#ifdef WITH_SHTNS
      !$omp parallel do default(shared)         &
      !$omp& private(nTheta, nPhi, fkin, fconv, fvisc, nThetaNHS)
#endif
      do nTheta=nThetaStart,nThetaStop
         nThetaNHS=(nTheta+1)/2
         fkinAS(nTheta) =0.0_cp
         fconvAS(nTheta)=0.0_cp
         fviscAS(nTheta)=0.0_cp
         fkin=0.0_cp
         fconv=0.0_cp
         fvisc=0.0_cp
         do nPhi=1,n_phi_max
            if ( l_anelastic_liquid ) then
               fconv=vr(nPhi,nTheta)*sr(nPhi,nTheta)
            else
               fconv=temp0(nr)*vr(nPhi,nTheta)*sr(nPhi,nTheta)     +    &
               &          ViscHeatFac*ThExpNb*alpha0(nr)*temp0(nr)*     &
               &          orho1(nr)*vr(nPhi,nTheta)*pr(nPhi,nTheta)
            end if

            fkin=half*or2(nR)*orho2(nR)*(osn2(nThetaNHS)*(           &
            &                  vt(nPhi,nTheta)*vt(nPhi,nTheta)  +    &
            &                  vp(nPhi,nTheta)*vp(nPhi,nTheta) )+    &
            &          or2(nR)*vr(nPhi,nTheta)*vr(nPhi,nTheta) )*    &
            &                             vr(nPhi,nTheta)

            if ( nR /= n_r_icb .and. nR /= n_r_cmb ) then
               fvisc=-two*visc(nR)*orho1(nR)*vr(nPhi,nTheta)*or2(nR)* (     &
               &                             dvrdr(nPhi,nTheta)             &
               & -(two*or1(nR)+two*third*beta(nR))*vr(nPhi,nTheta) )-       &
               &                       visc(nR)*orho1(nR)*vt(nPhi,nTheta)*  &
               &                           osn2(nThetaNHS)* (               &
               &                       or2(nR)*dvrdt(nPhi,nTheta)           &
               &                              +dvtdr(nPhi,nTheta)           &
               &       -(two*or1(nR)+beta(nR))*vt(nPhi,nTheta) )  -         &
               &       visc(nR)*orho1(nR)*vp(nPhi,nTheta)*                  &
               &                              osn2(nThetaNHS)* (            &
               &                       or2(nR)*dvrdp(nPhi,nTheta)           &
               &                              +dvpdr(nPhi,nTheta)           &
               &       -(two*or1(nR)+beta(nR))*vp(nPhi,nTheta) )
            end if

            fkinAS(nTheta) = fkinAS(nTheta)+fkin
            fconvAS(nTheta)=fconvAS(nTheta)+fconv
            fviscAS(nTheta)=fviscAS(nTheta)+fvisc
         end do
         fkinAS(nTheta) =phiNorm* fkinAS(nTheta)
         fconvAS(nTheta)=phiNorm*fconvAS(nTheta)
         fviscAS(nTheta)=phiNorm*fviscAS(nTheta)
      end do
#ifdef WITH_SHTNS
      !$omp end parallel do
#endif

      if ( l_mag_nl) then
#ifdef WITH_SHTNS
         !$omp parallel do default(shared)         &
         !$omp& private(nTheta, nPhi, fkin, fconv, fvisc, nThetaNHS)
#endif
         do nTheta=nThetaStart,nThetaStop
            nThetaNHS=(nTheta+1)/2
            fresAS(nTheta) =0.0_cp
            fpoynAS(nTheta)=0.0_cp
            fres=0.0_cp
            fpoyn=0.0_cp
            do nPhi=1,n_phi_max
                fres =osn2(nThetaNHS)*(                            &
                &              cbt(nPhi,nTheta)*bp(nPhi,nTheta)  - &
                &              cbp(nPhi,nTheta)*bt(nPhi,nTheta) )

                fpoyn=-orho1(nR)*or2(nR)*osn2(nThetaNHS)*(                     &
                &           vp(nPhi,nTheta)*br(nPhi,nTheta)*bp(nPhi,nTheta)  - &
                &           vr(nPhi,nTheta)*bp(nPhi,nTheta)*bp(nPhi,nTheta)  - &
                &           vr(nPhi,nTheta)*bt(nPhi,nTheta)*bt(nPhi,nTheta)  + &
                &           vt(nPhi,nTheta)*br(nPhi,nTheta)*bt(nPhi,nTheta) )

                fresAS(nTheta) = fresAS(nTheta)+fres
                fpoynAS(nTheta)=fpoynAS(nTheta)+fpoyn
            end do
            fresAS(nTheta) =phiNorm* fresAS(nTheta)
            fpoynAS(nTheta)=phiNorm*fpoynAS(nTheta)
         end do
#ifdef WITH_SHTNS
         !$omp end parallel do
#endif

#ifdef WITH_SHTNS
         call spat_to_SH_axi_dist(fresAS,fresLMr)
         call spat_to_SH_axi_dist(fpoynAS,fpoynLMr)
#else
         call legTFAS2(fresLMr,fpoynLMr,fresAS,fpoynAS,l_max+1,nThetaStart, &
              &        n_theta_loc)
#endif
      end if

      !-- Add contribution from thetas in block:
#ifdef WITH_SHTNS
      call spat_to_SH_axi_dist(fviscAS,fviscLMr)
      call spat_to_SH_axi_dist(fconvAS,fconvLMr)
      call spat_to_SH_axi_dist(fkinAS,fkinLMr)
#else
      call legTFAS(fviscLMr,fviscAS,l_max+1,nThetaStart,n_theta_loc)
      call legTFAS2(fconvLMr,fkinLMr,fconvAS,fkinAS,l_max+1,nThetaStart,n_theta_loc)
#endif

   end subroutine get_fluxes
!------------------------------------------------------------------------------
   subroutine get_helicity(vr,vt,vp,cvr,dvrdt,dvrdp,dvtdr,dvpdr,HelLMr, &
              &            Hel2LMr,HelnaLMr,Helna2LMr,nR)
      !
      !   Calculates axisymmetric contributions of helicity HelLMr and
      !   helicity**2  Hel2LMr in (l,m=0,r) space.
      !

      !-- Input of variables
      integer,  intent(in) :: nR
      real(cp), intent(in) :: vr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: vt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: vp(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: cvr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvrdt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvrdp(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvtdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvpdr(nrp,nThetaStart:nThetaStop)

      !-- Output variables:
      real(cp), intent(out) :: HelLMr(l_max+1)
      real(cp), intent(out) :: Hel2LMr(l_max+1)
      real(cp), intent(out) :: HelnaLMr(l_max+1)
      real(cp), intent(out) :: Helna2LMr(l_max+1)

      !-- Local variables:
      integer :: nTheta
      integer :: nPhi
      real(cp) :: HelAS(nThetaStart:nThetaStop),Hel2AS(nThetaStart:nThetaStop)
      real(cp) ::HelnaAS(nThetaStart:nThetaStop),Helna2AS(nThetaStart:nThetaStop)
      real(cp) :: Helna, Hel, phiNorm
      real(cp) :: vras,vtas,vpas,cvras,dvrdtas,dvrdpas,dvtdras,dvpdras
      real(cp) :: vrna,vtna,vpna,cvrna,dvrdtna,dvrdpna,dvtdrna,dvpdrna

      !-- Remark: 2pi not used the normalization below
      !-- this is why we have a 2pi factor after radial integration
      !-- in the subroutine outHelicity()
      phiNorm=one/real(n_phi_max,cp)

      !--- Helicity:
#ifdef WITH_SHTNS
      !$omp parallel do default(shared)                     &
      !$omp& private(nTheta, nPhi, Hel, Helna)              &
      !$omp& private(vrna, cvrna, vtna, vpna)               &
      !$omp& private(dvrdpna, dvpdrna, dvtdrna, dvrdtna)
#endif
      do nTheta=nThetaStart,nThetaStop
         HelAS(nTheta)   =0.0_cp
         Hel2AS(nTheta)  =0.0_cp
         HelnaAS(nTheta) =0.0_cp
         Helna2AS(nTheta)=0.0_cp
         vras=0.0_cp
         cvras=0.0_cp
         vtas=0.0_cp
         vpas=0.0_cp
         dvrdpas=0.0_cp
         dvpdras=0.0_cp
         dvtdras=0.0_cp
         dvrdtas=0.0_cp
         do nPhi=1,n_phi_max
            vras=vras+vr(nPhi,nTheta)
            cvras=cvras+cvr(nPhi,nTheta)
            vtas=vtas+vt(nPhi,nTheta)
            vpas=vpas+vp(nPhi,nTheta)
            dvrdpas=dvrdpas+dvrdp(nPhi,nTheta)
            dvpdras=dvpdras+dvpdr(nPhi,nTheta)
            dvtdras=dvtdras+dvtdr(nPhi,nTheta)
            dvrdtas=dvrdtas+dvrdt(nPhi,nTheta)
         end do
         vras=vras*phiNorm
         cvras=cvras*phiNorm
         vtas=vtas*phiNorm
         vpas=vpas*phiNorm
         dvrdpas=dvrdpas*phiNorm
         dvpdras=dvpdras*phiNorm
         dvtdras=dvtdras*phiNorm
         dvrdtas=dvrdtas*phiNorm
         do nPhi=1,n_phi_max
            vrna   =   vr(nPhi,nTheta)-vras
            cvrna  =  cvr(nPhi,nTheta)-cvras
            vtna   =   vt(nPhi,nTheta)-vtas
            vpna   =   vp(nPhi,nTheta)-vpas
            dvrdpna=dvrdp(nPhi,nTheta)-dvrdpas
            dvpdrna=dvpdr(nPhi,nTheta)-beta(nR)*vp(nPhi,nTheta) &
            &       -dvpdras+beta(nR)*vpas
            dvtdrna=dvtdr(nPhi,nTheta)-beta(nR)*vt(nPhi,nTheta) &
            &       -dvtdras+beta(nR)*vtas
            dvrdtna=dvrdt(nPhi,nTheta)-dvrdtas
            Hel=or4(nR)*orho2(nR)*vr(nPhi,nTheta)*cvr(nPhi,nTheta) +  &
            &             or2(nR)*orho2(nR)*O_sin_theta_E2(nTheta)* ( &
            &                                       vt(nPhi,nTheta) * &
            &                          ( or2(nR)*dvrdp(nPhi,nTheta) - &
            &                                    dvpdr(nPhi,nTheta) + &
            &                         beta(nR)*   vp(nPhi,nTheta) ) + &
            &                                       vp(nPhi,nTheta) * &
            &                          (         dvtdr(nPhi,nTheta) - &
            &                           beta(nR)*   vt(nPhi,nTheta) - &
            &                            or2(nR)*dvrdt(nPhi,nTheta) ) )
            Helna=                      or4(nR)*orho2(nR)*vrna*cvrna + &
            &              or2(nR)*orho2(nR)*O_sin_theta_E2(nTheta)* ( &
            &                       vtna*( or2(nR)*dvrdpna-dvpdrna ) + &
            &                       vpna*( dvtdrna-or2(nR)*dvrdtna ) )

            HelAS(nTheta)   =HelAS(nTheta) +Hel
            Hel2AS(nTheta)  =Hel2AS(nTheta)+Hel*Hel
            HelnaAS(nTheta) =HelnaAS(nTheta) +Helna
            Helna2AS(nTheta)=Helna2AS(nTheta)+Helna*Helna
         end do
         HelAS(nTheta) =phiNorm*HelAS(nTheta)
         Hel2AS(nTheta)=phiNorm*Hel2AS(nTheta)
         HelnaAS(nTheta) =phiNorm*HelnaAS(nTheta)
         Helna2AS(nTheta)=phiNorm*Helna2AS(nTheta)
      end do
#ifdef WITH_SHTNS
      !$omp end parallel do
#endif

      !-- Add contribution from thetas in block:
#ifdef WITH_SHTNS
      call spat_to_SH_axi_dist(HelAS, HelLMr)
      call spat_to_SH_axi_dist(Hel2AS, Hel2LMr)
      call spat_to_SH_axi_dist(HelnaAS, HelnaLMr)
      call spat_to_SH_axi_dist(Helna2AS, Helna2LMr)
#else
      call legTFAS2(HelLMr,Hel2LMr,HelAS,Hel2AS,l_max+1,nThetaStart,n_theta_loc)
      call legTFAS2(HelnaLMr,Helna2LMr,HelnaAS,Helna2AS,l_max+1,nThetaStart,&
           &        n_theta_loc)
#endif

   end subroutine get_helicity
!------------------------------------------------------------------------------
   subroutine get_visc_heat(vr,vt,vp,cvr,dvrdr,dvrdt,dvrdp,dvtdr,&
              &             dvtdp,dvpdr,dvpdp,viscLMr,nR)
      !
      !   Calculates axisymmetric contributions of the viscous heating
      !
      !

      !-- Input of variables
      integer,  intent(in) :: nR
      real(cp), intent(in) :: vr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: vt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: vp(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: cvr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvrdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvrdt(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvrdp(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvtdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvtdp(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvpdr(nrp,nThetaStart:nThetaStop)
      real(cp), intent(in) :: dvpdp(nrp,nThetaStart:nThetaStop)

      !-- Output variables:
      real(cp), intent(out) :: viscLMr(l_max+1)

      !-- Local variables:
      integer :: nTheta, nPhi, nThetaNHS
      real(cp) :: viscAS(nThetaStart:nThetaStop),vischeat,csn2, phinorm

      phiNorm=two*pi/real(n_phi_max,cp)

#ifdef WITH_SHTNS
      !$omp parallel do default(shared)             &
      !$omp& private(nTheta, nPhi, vischeat, csn2, nThetaNHS)
#endif
      do nTheta=nThetaStart, nThetaStop
         nThetaNHS=(nTheta+1)/2
         csn2     =cosn2(nThetaNHS)
         if ( mod(nTheta,2) == 0 ) csn2=-csn2 ! South, odd function in theta

         viscAS(nTheta)=0.0_cp
         do nPhi=1,n_phi_max
            vischeat=         or2(nR)*orho1(nR)*visc(nR)*(       &
            &     two*(                     dvrdr(nPhi,nTheta) - & ! (1)
            &     (two*or1(nR)+beta(nR))*vr(nphi,nTheta) )**2  + &
            &     two*( csn2*                  vt(nPhi,nTheta) + &
            &                               dvpdp(nphi,nTheta) + &
            &                               dvrdr(nPhi,nTheta) - & ! (2)
            &     or1(nR)*               vr(nPhi,nTheta) )**2  + &
            &     two*(                     dvpdp(nphi,nTheta) + &
            &           csn2*                  vt(nPhi,nTheta) + & ! (3)
            &     or1(nR)*               vr(nPhi,nTheta) )**2  + &
            &          ( two*               dvtdp(nPhi,nTheta) + &
            &                                 cvr(nPhi,nTheta) - & ! (6)
            &      two*csn2*             vp(nPhi,nTheta) )**2  + &
            &                                osn2(nThetaNHS) * ( &
            &         ( r(nR)*              dvtdr(nPhi,nTheta) - &
            &           (two+beta(nR)*r(nR))*  vt(nPhi,nTheta) + & ! (4)
            &     or1(nR)*            dvrdt(nPhi,nTheta) )**2  + &
            &         ( r(nR)*              dvpdr(nPhi,nTheta) - &
            &           (two+beta(nR)*r(nR))*  vp(nPhi,nTheta) + & ! (5)
            &     or1(nR)*            dvrdp(nPhi,nTheta) )**2 )- &
            &    two*third*(  beta(nR)*        vr(nPhi,nTheta) )**2 )

            viscAS(nTheta)=viscAS(nTheta)+vischeat
         end do
         viscAS(nTheta)=phiNorm*viscAS(nTheta)
      end do
#ifdef WITH_SHTNS
      !$omp end parallel do
#endif

#ifdef WITH_SHTNS
      call spat_to_SH_axi_dist(viscAS, viscLMr)
#else
      call legTFAS(viscLMr,viscAS,l_max+1,nThetaStart,n_theta_loc)
#endif

   end subroutine get_visc_heat
!------------------------------------------------------------------------------
end module nl_special_calc

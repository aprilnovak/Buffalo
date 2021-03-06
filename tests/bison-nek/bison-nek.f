c-----------------------------------------------------------------------
C
C  USER SPECIFIED ROUTINES:
C
C     - boundary conditions
C     - initial conditions
C     - variable properties
C     - local acceleration for fluid (a)
C     - forcing function for passive scalar (q)
C     - general purpose routine for checking errors etc.
C
c-----------------------------------------------------------------------
      subroutine uservp (ix,iy,iz,eg)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'
      integer e,f,eg
      udiff =0.
      utrans=0.
      return
      end
c-----------------------------------------------------------------------
      subroutine userf  (ix,iy,iz,eg)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'
      integer e,f,eg
      ffx=0.0
      ffy=0.0
      ffz=0.0     
      return
      end
c-----------------------------------------------------------------------
      subroutine userq  (ix,iy,iz,eg)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'

      integer e,f,eg
c     e = gllel(eg)

      qvol   = 0.0

      return
      end
c-----------------------------------------------------------------------
      subroutine userchk
      include 'SIZE'
      include 'TOTAL'
      parameter (nl_max=100)
      parameter (nf_max=100)
      common/expansion_tdata/n_legendre, m_fourier
      common/expansion_tcoef/coeff_tij(nl_max,nf_max)
      common/expansion_fcoef/coeff_fij(nl_max,nf_max)
      common/expansion_recon/flux_recon(lx1,ly1,lz1,lelt)
      common/test_passing/ flux_moose, temp_nek 
      real sint, sint1, sarea, sarea1, wtmp
      integer e, f 

      n1=nelt*lx1*ly1*lz1
      n2=nelt*lx2*ly2*lz2

      pmin=glmin(pr,n2)
      pmax=glmax(pr,n2)
      wmin=glmin(vz,n1)
      wmax=glmax(vz,n1)
      tmin=glmin(t,n1)
      tmax=glmax(t,n1)

      ifflow=.false. 

c      if (istep.eq.0) then
c         call rzero(t,n1) 
c      endif

      sint1=0.0
      sarea1=0.0

      do e=1,lelt
        do f=1,6
          call surface_int(sint,sarea,t,e,f)
          if (cbc(f,e,1).eq.'W  ') then
           sint1=sint1+sint  
           sarea1=sarea1+sarea
          endif          
         enddo 
      enddo

      call  gop(sint1,wtmp,'+  ',1)
      call  gop(sarea1,wtmp,'+  ',1)

      temp_nek=sint1/sarea1

      sint1=0.0
      sarea1=0.0

      do e=1,lelt
        do f=1,6
          call surface_int(sint,sarea,flux_recon,e,f)
          if (cbc(f,e,1).eq.'W  ') then
           sint1=sint1+sint
           sarea1=sarea1+sarea
          endif
         enddo
      enddo

      call  gop(sint1,wtmp,'+  ',1)
      call  gop(sarea1,wtmp,'+  ',1)

      flux_moose=sint1/sarea1

      call heat_balance(flux_moose)
      
      if (nid.eq.0) then
         write(6,*)"*** Temperature: ",tmin," - ",tmax
         write(6,*)"*** Average Temperature: ",temp_nek,coeff_tij(1,1)
         write(6,*)"*** Average Flux: ",flux_moose,coeff_fij(1,1)
      endif

c     Will this be overwritten -----------------
c      write(6,*)"*** Setting polynomial orders ..." 
      n_legendre=10
      m_fourier=5
c-----------------------------------------------

c This is for testing -----------
c      call flux_reconstruction()
c      call nek_expansion()
c      call nek_diag()
c      if (nid.eq.0) write(6,*)" *** Expansion done"
c      call nek_testp() 
c      call exitt()
c--------------------------------

c This is to test coefficients with MOOSE --
c      do i0=1,n_legendre
c        do j0=1,m_fourier
c        if (nid.eq.0) write(6,*)"C(",i0,",",j0,")=",
c     &      coeff_fij(i0,j0)
c        enddo 
c      enddo
c------------------------------------------
      return
      end
c-----------------------------------------------------------------------
      subroutine userbc (ix,iy,iz,iside,ieg)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'
      
      common/test_passing/ flux_moose, temp_nek
      common/expansion_recon/flux_recon(lx1,ly1,lz1,lelt)

      integer e,ieg
      real ucx, ucy, ucz, ucy_e, yy 

      e=gllel(ieg)

      zz  = zm1(ix,iy,iz,e)
      xx  = xm1(ix,iy,iz,e)
      yy  = ym1(ix,iy,iz,e)
      rr  = sqrt(xx**2 + yy**2)

      ux = 0.0
      uy = 0.0
      uz = 1.0
      temp = 0.0
      flux = flux_recon(ix,iy,iz,e) !flux_moose

      return
      end
c-----------------------------------------------------------------------
      subroutine useric (ix,iy,iz,ieg)
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'

      integer idum, e
      save    idum
      data    idum / 0 /

      if (idum.eq.0) idum = 99 + nid
      eps = .35

      uz=0.0
      uy=0.0
      ux=0.0
      temp=0

      return
      end
c-----------------------------------------------------------------------
      subroutine usrdat
      include 'SIZE'
      include 'TOTAL'

      return
      end
c-----------------------------------------------------------------------
      subroutine usrdat2
      include 'SIZE'
      include 'TOTAL'

      param(66) = 4.   ! These give the std nek binary i/o and are 
      param(67) = 4.   ! good default values
      ifuservp=.false.

      return
      end
c-----------------------------------------------------------------------
      subroutine usrdat3
      include 'SIZE'
      include 'TOTAL'
c
      return
      end

C=======================================================================
      subroutine nek_init_step()
      include 'SIZE'
      include 'TSTEP'
      include 'INPUT'
      include 'CTIMER'
      real*4 papi_mflops
      integer*8 papi_flops
      integer icall, kstep, i, pstep
      common /cht_coupler/ pstep
      save icall
 
      if (icall.eq.0) then
      call nekgsync()
      if (instep.eq.0) then
        if(nid.eq.0) write(6,'(/,A,/,A,/)')
     &     ' nsteps=0 -> skip time loop',
     &     ' running solver in post processing mode'
      else
        if(nio.eq.0) write(6,'(/,A,/)') 'Starting time loop ...'
      endif
      isyc  = 0
      itime = 0
      if(ifsync) isyc=1
      itime = 1
      call nek_comm_settings(isyc,itime)
      call nek_comm_startstat()
      istep  = 0
      icall  = 1
      endif

      istep=istep+1

      if (lastep .eq. 1) then
        pstep=2
      else
        call nek_advance
        pstep=2
      endif

      return
      end
C=======================================================================
      subroutine nek_step()

      include 'SIZE'
      include 'TSTEP'
      include 'INPUT'
      include 'CTIMER'
      common /cht_coupler/ pstep
      integer pstep

      pstep=pstep+1
      call heat(pstep)

      return
      end
C=======================================================================
      subroutine nek_finalize_step()
      include 'SIZE'
      include 'TSTEP'
      include 'INPUT'
      include 'CTIMER'
      common /cht_coupler/ pstep
      integer pstep 

      real*4 papi_mflops
      integer*8 papi_flops
      integer icall, kstep, knstep, i

      if (param(103).gt.0)   call q_filter      (param(103))
      call setup_convect (pstep)  ! Save convective velocity _after_ filter

      call userchk
      call prepost (.false.,'his')
      call in_situ_check()

      if (mod(istep,nsteps).eq.0) lastep=1
      call nek_comm_settings(isyc,0)
      call comment

      return
      end
C=======================================================================
      subroutine nek_expansion()

      parameter (nl_max=100)
      parameter (nf_max=100)

      include 'SIZE'
      include 'TOTAL'       
      common/expansion_tdata/n_legendre, m_fourier
      common/expansion_tcoef/coeff_tij(nl_max,nf_max)  
      integer e,f

      real*8 fmode(lx1,ly1,lz1,lelt), cache(lx1,ly1,lz1,lelt) 
      real*8 sint, sint1

      ntot=nx1*ny1*nz1*nelt

      zmin=glmin(zm1,ntot)
      zmax=glmax(zm1,ntot)

      call rzero(fmode,ntot)
         do i0=1,n_legendre
           do j0=1,m_fourier
             call nek_mode(fmode,i0,j0)
             sint1=0.0 
             do e=1,nelt
               do f=1,6
                 sint=0.0
                 if (cbc(f,e,1).eq.'W  ') then
                   call col3(cache,fmode,t,ntot)
                   call surface_int(sint,sarea,cache,e,f)
                   sint1=sint1+sint
                 endif
               enddo
             enddo
          call  gop(sint1,wtmp,'+  ',1)
!                                   
          coeff_tij(i0,j0)=sint1*2.0/(0.5*(zmax-zmin))
!         Note that R=0.5 here!!!!
        enddo 
      enddo

c     For Testing 
      call nek_testp()
      return
      end
C=======================================================================
      subroutine nek_diag()
      parameter (nl_max=100)
      parameter (nf_max=100)
      include 'SIZE'
      include 'TOTAL'
      common/expansion_tdata/n_legendre, m_fourier
      common/expansion_tcoef/coeff_tij(nl_max,nf_max)
      common/diags_coeff/diag_c(nl_max,nf_max)
      integer e,f

      real*8 fmode(lx1,ly1,lz1,lelt)
      real*8 cache(lx1,ly1,lz1,lelt)
      real*8 sint, sint1

      ntot=nx1*ny1*nz1*nelt

      zmin=glmin(zm1,ntot)
      zmax=glmax(zm1,ntot)

      call rzero(fmode,ntot)
         do i0=1,n_legendre
           do j0=1,m_fourier
             call nek_mode(fmode,i0,j0)  
             sint1=0.0
             do e=1,nelt
               do f=1,6
                 sint=0.0
                 if (cbc(f,e,1).eq.'W  ') then
                   call col3(cache,fmode,fmode,ntot)
                   call surface_int(sint,sarea,cache,e,f)
                   sint1=sint1+sint
                 endif
               enddo
             enddo
          call  gop(sint1,wtmp,'+  ',1)
          diag_c(i0,j0)=sint1*2.0/(0.5*(zmax-zmin))
          if (nid.eq.0) write(6,*)i0,j0,diag_c(i0,j0)
        enddo
      enddo

      return
      end
C=======================================================================
      subroutine nek_testp()
      parameter (nl_max=100)
      parameter (nf_max=100)
      include 'SIZE'
      include 'TOTAL'
      common/expansion_tdata/n_legendre, m_fourier
      common/expansion_tcoef/coeff_tij(nl_max,nf_max)
      integer e,f
      real*8 fmode(lx1,ly1,lz1,lelt), cache(lx1,ly1,lz1,lelt)
      real*8 fun(lx1,ly1,lz1,lelt) 
      ntot=nx1*ny1*nz1*nelt
      call rzero(fmode,ntot)
      call rzero(fun,ntot)   
         do i0=1,n_legendre
           do j0=1,m_fourier
             call nek_mode(fmode,i0,j0)
             do i=1,ntot
             fun(i,1,1,1)=fun(i,1,1,1)+fmode(i,1,1,1)*coeff_tij(i0,j0) 
             enddo  
          enddo
         enddo
      call rzero(cache,ntot) 
      call sub3(cache,fun,t,ntot)
      do i=1,ntot
        c1=cache(i,1,1,1)**2
        cache(i,1,1,1)=c1 
      enddo
 
      sint1=0.0
      sarea1=0.0
      do e=1,lelt
        do f=1,6
          call surface_int(sint,sarea,cache,e,f)
          if (cbc(f,e,1).eq.'W  ') then
           sint1=sint1+sint
           sarea1=sarea1+sarea
          endif
         enddo
      enddo
      call  gop(sint1,wtmp,'+  ',1)
      call  gop(sarea1,wtmp,'+  ',1)

      er_avg=sqrt(sint1/sarea1)
      if (nid.eq.0) write(6,*)"Error: ",er_avg
      return
      end
C=======================================================================
      subroutine nek_mode(fmode,im,jm)
      include 'SIZE'
      include 'TOTAL'
      integer e,f
      real*8 fmode(lx1,ly1,lz1,lelt) 
      ntot=nx1*ny1*nz1*nelt
      zmin=glmin(zm1,ntot)
      zmax=glmax(zm1,ntot)
             do e=1,nelt
               do f=1,6
                 if (cbc(f,e,1).eq.'W  ') then
                   call dsset(nx1,ny1,nz1)
                   iface  = eface1(f)
                   js1    = skpdat(1,iface)
                   jf1    = skpdat(2,iface)
                   jskip1 = skpdat(3,iface)
                   js2    = skpdat(4,iface)
                   jf2    = skpdat(5,iface)
                   jskip2 = skpdat(6,iface)
                   do j2=js2,jf2,jskip2
                     do j1=js1,jf1,jskip1
                       x=xm1(j1,j2,1,e)
                       y=ym1(j1,j2,1,e)
                       z=zm1(j1,j2,1,e)
                       z_leg=2*((z-zmin)/zmax)-1
                       theta=atan2(y,x)
                       fmode(j1,j2,1,e)=
     &                 pl_leg(z_leg,im-1)*fl_four(theta,jm-1)
                     enddo
                   enddo
                 endif
              enddo
            enddo
      return
      end 
c-----------------------------------------------------------------------
      subroutine flux_reconstruction()
      include 'SIZE'
      include 'TOTAL'
      parameter (nl_max=100)
      parameter (nf_max=100) 
      common/expansion_tdata/n_legendre, m_fourier
      common/expansion_tcoef/coeff_tij(nl_max,nf_max)
      common/expansion_fcoef/coeff_fij(nl_max,nf_max)
      common/expansion_recon/flux_recon(lx1,ly1,lz1,lelt)
      integer e,f
      real*8 coeff_base, flux_base, flux_moose 
      real*8 fmode(lx1,ly1,lz1,lelt)
      ntot=nx1*ny1*nz1*nelt

c     --------------------------------------
c     The flux from MOOSE must have proper sign
c     --------------------------------------
      coeff_base=-1.0 
      flux_base=0.25 ! from energy conservation in the problem
c     --------------------------------------

      call rzero(flux_recon,ntot)
         do i0=1,n_legendre
           do j0=1,m_fourier
             call rzero(fmode,ntot)
             call nek_mode(fmode,i0,j0)
             do i=1,ntot
             flux_recon(i,1,1,1)= flux_recon(i,1,1,1)
     &                  + coeff_base*fmode(i,1,1,1)*coeff_fij(i0,j0)
             enddo
          enddo
         enddo

c---- Below is for testing
c             do i=1,ntot
c             flux_recon(i,1,1,1)= 0.0
c             enddo
c--------------------------

c---- Renormalization
      sint1=0.0
      sarea1=0.0

      do e=1,lelt
        do f=1,6
          call surface_int(sint,sarea,flux_recon,e,f)
          if (cbc(f,e,1).eq.'W  ') then
           sint1=sint1+sint
           sarea1=sarea1+sarea
          endif
         enddo
      enddo

      call  gop(sint1,wtmp,'+  ',1)
      call  gop(sarea1,wtmp,'+  ',1)

      flux_moose=sint1/sarea1
      do i=1,ntot
         flux_recon(i,1,1,1)= flux_recon(i,1,1,1)*flux_base/flux_moose
      enddo
c-----------------------
      return
      end
c-----------------------------------------------------------------------
      function pl_leg(x,n)
!======================================
!    calculates Legendre polynomials Pn(x)
!    using the recurrence relation
!    if n > 100 the function retuns 0.0
!======================================
      real*8 pl,pl_leg
      real*8 x
      real*8 pln(0:n)
      integer n, k
      pln(0) = 1.0
      pln(1) = x
      if (n.le.1) then
        pl = pln(n)
          else
            do k=1,n-1
              pln(k+1)=
     &  ((2.0*k+1.0)*x*pln(k)-dble(k)*pln(k-1))/(dble(k+1))
            end do
            pl = pln(n)
      end if
      pl_leg=pl*sqrt(dble(2*n+1)/2.0)
      return 
      end
!======================================
      function fl_four(x,n)
      real*8 fl_four,pi
      real*8 x, A
      integer n, k
      pi=4.0*atan(1.0)
      A=1.0/sqrt(2*pi)
      if (n.gt.0) A=1.0/sqrt(pi)  
      fl_four=A*cos(n*x)    
c       fl_four=1.0/sqrt(pi)
      return 
      end
c-----------------------------------------------------------------------
      subroutine heat_balance(fflux)
      include 'SIZE'
      include 'TOTAL'
      real sint, sint1, sarea, sarea1, wtmp, fflux
      real cache(lx1,ly1,lz1,lelt),dtdz(lx1,ly1,lz1,lelt),
     & dtdy(lx1,ly1,lz1,lelt),
     & dtdx(lx1,ly1,lz1,lelt)
      integer e, f

      n1=nelt*lx1*ly1*lz1
      n2=nelt*lx2*ly2*lz2
      nxyz=lx1*ly1*lz1
      call gradm1(dtdx,dtdy,dtdz,t(1,1,1,1,1))

      sint1=0.0
      sarea1=0.0
      do e=1,lelt
        do i=1,nxyz
          cache(i,1,1,e)=t(i,1,1,e,1)*vz(i,1,1,e)
        enddo
        do f=1,6
          call surface_int(sint,sarea,cache,e,f)
          if (cbc(f,e,1).eq.'O  ') then
           sint1=sint1+sint
           sarea1=sarea1+sarea
          endif
         enddo
      enddo
      call  gop(sint1,wtmp,'+  ',1)
      test_flux=sint1
      
      sint1=0.0
      sarea1=0.0
      do e=1,lelt
        do f=1,6
          call surface_int(sint,sarea,dtdz,e,f)
          if (cbc(f,e,1).eq.'v  ') then
           sint1=sint1+sint
           sarea1=sarea1+sarea
          endif
         enddo
      enddo
      call  gop(sint1,wtmp,'+  ',1)
      call  gop(sarea1,wtmp,'+  ',1)
      flux_inlet=sint1

      sint1=0.0
      sarea1=0.0
      do e=1,lelt
        do f=1,6
          call surface_int(sint,sarea,vz,e,f)
          if (cbc(f,e,1).eq.'W  ') then
           sarea1=sarea1+sarea
          endif
         enddo
      enddo
      call  gop(sarea1,wtmp,'+  ',1)

      if (nid.eq.0) then
         rr_loss=
     &   flux_inlet*param(8)/(test_flux+flux_inlet*param(8))
         write(6,*)"*** Heat balance: ",
     &   sarea1*fflux,test_flux+flux_inlet*param(8)
         write(6,*)"*** Heat loss: ",rr_loss*100.0," %"
      endif

      return
      end
c-----------------------------------------------------------------------
c
c automatically added by makenek
      subroutine usrsetvert(glo_num,nel,nx,ny,nz) ! to modify glo_num
      integer*8 glo_num(1)
      return
      end
c
c automatically added by makenek
      subroutine usrflt(rmult) ! user defined filter
      include 'SIZE'
      real rmult(lx1)
      call rone(rmult,lx1)
      return
      end
c
c automatically added by makenek
      subroutine userflux ! user defined flux
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'
      real fluxout(lx1*lz1)
      return
      end
c
c automatically added by makenek
      subroutine userEOS ! user defined EOS
      include 'SIZE'
      include 'TOTAL'
      include 'NEKUSE'

      return
      end

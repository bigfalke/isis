      subroutine isissubplx (f,n,tol,maxnfe,mode,scale,x,fx,nfe,
     &                   work,iwork,iflag)
c
      integer n,maxnfe,mode,nfe,iwork(*),iflag
      double precision f,tol,scale(*),x(n),fx,work(*)
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c subplx uses the subplex method to solve unconstrained
c optimization problems.  The method is well suited for
c optimizing objective functions that are noisy or are
c discontinuous at the solution.
c
c subplx sets default optimization options by calling the
c subroutine subopt.  The user can override these defaults
c by calling subopt prior to calling subplx, changing the
c appropriate common variables, and setting the value of
c mode as indicated below.
c
c By default, subplx performs minimization.
c
c input
c
c   f      - user supplied function f(n,x) to be optimized,
c            declared external in calling routine
c
c   n      - problem dimension
c
c   tol    - relative error tolerance for x (tol .ge. 0.)
c
c   maxnfe - maximum number of function evaluations
c
c   mode   - integer mode switch with binary expansion
c            (bit 1) (bit 0) :
c            bit 0 = 0 : first call to subplx
c                  = 1 : continuation of previous call
c            bit 1 = 0 : use default options
c                  = 1 : user set options
c
c   scale  - scale and initial stepsizes for corresponding
c            components of x
c            (If scale(1) .lt. 0.,
c            abs(scale(1)) is used for all components of x,
c            and scale(2),...,scale(n) are not referenced.)
c
c   x      - starting guess for optimum
c
c   work   - double precision work array of dimension .ge.
c            2*n + nsmax*(nsmax+4) + 1
c            (nsmax is set in subroutine subopt.
c            default: nsmax = min(5,n))
c
c   iwork  - integer work array of dimension .ge.
c            n + int(n/nsmin)
c            (nsmin is set in subroutine subopt.
c            default: nsmin = min(2,n))
c
c output
c
c   x      - computed optimum
c
c   fx     - value of f at x
c
c   nfe    - number of function evaluations
c
c   iflag  - error flag
c            = -2 : invalid input
c            = -1 : maxnfe exceeded
c            =  0 : tol satisfied
c            =  1 : limit of machine precision
c            =  2 : fstop reached (fstop usage is determined
c                   by values of options minf, nfstop, and
c                   irepl. default: f(x) not tested against
c                   fstop)
c            iflag should not be reset between calls to
c            subplx.
c
c common
c
      integer nsmin,nsmax,irepl,ifxsw,nfstop,nfxe
      double precision alpha,beta,gamma,delta,psi,omega,
     *     bonus,fstop,fxstat,ftest
      logical minf,initx,newx
c
      common /usubc/ alpha,beta,gamma,delta,psi,omega,nsmin,
     *               nsmax,irepl,ifxsw,bonus,fstop,nfstop,
     *               nfxe,fxstat(4),ftest,minf,initx,newx
c
      double precision fbonus,sfstop,sfbest
      logical new
c
      common /isubc/ fbonus,sfstop,sfbest,new
c
c local variables
c
      integer i,j,ifsptr,ins,insfnl,insptr,ipptr,isptr,
     *        istep,istptr,ns,nsubs
      double precision bnsfac(3,2),dum(1),scl,sfx,xpscl
      logical cmode
c
      save
c
c subroutines and functions
c
      external f,isis_sortd,isis_evalf,isis_partx,isis_setstp
      external isis_simplx,isis_subopt
c   blas
      external isis_dcopy
c   fortran
      intrinsic abs,mod
c
c data
c
      data ((bnsfac(i,j),i=1,3),j=1,2) /-1.d0,-2.d0,0.d0,
     *      1.d0,0.d0,2.d0/
c-----------------------------------------------------------
c
      if (mod(mode,2) .eq. 0) then
c
c       first call, check input
c
        if (n .lt. 1) go to 120
        if (tol .lt. 0.d0) go to 120
        if (maxnfe .lt. 1) go to 120
        if (scale(1) .ge. 0.d0) then
          do 10 i = 1,n
            xpscl = x(i)+scale(i)
            if (xpscl .eq. x(i)) go to 120
   10     continue
        else
          scl = abs(scale(1))
          do 20 i = 1,n
            xpscl = x(i)+scl
            if (xpscl .eq. x(i)) go to 120
   20     continue
        end if
        if (mod(mode/2,2) .eq. 0) then
          call isis_subopt (n)
        else
          if (alpha .le. 0.d0) go to 120
          if (beta .le. 0.d0 .or. beta .ge. 1.d0) go to 120
          if (gamma .le. 1.d0) go to 120
          if (delta .le. 0.d0 .or. delta .ge. 1.d0)
     *        go to 120
          if (psi .le. 0.d0 .or. psi .ge. 1.d0) go to 120
          if (omega .le. 0.d0 .or. omega .ge. 1.d0)
     *        go to 120
          if (nsmin .lt. 1 .or. nsmax .lt. nsmin .or.
     *        n .lt. nsmax) go to 120
          if (n .lt. ((n-1)/nsmax+1)*nsmin) go to 120
          if (irepl .lt. 0 .or. irepl .gt. 2) go to 120
          if (ifxsw .lt. 1 .or. ifxsw .gt. 3) go to 120
          if (bonus .lt. 0.d0) go to 120
          if (nfstop .lt. 0) go to 120
        end if
c
c       initialization
c
        istptr = n+1
        isptr = istptr+n
        ifsptr = isptr+nsmax*(nsmax+3)
        insptr = n+1
cjch-start  replace isis_dcopy calls with explicit loop
cjch        if (scale(1) .gt. 0.d0) then
cjch          call isis_dcopy (n,scale,1,work,1)
cjch          call isis_dcopy (n,scale,1,work(istptr),1)
cjch        else
cjch          call isis_dcopy (n,scl,0,work,1)
cjch          call isis_dcopy (n,scl,0,work(istptr),1)
cjch        end if
        if (scale(1) .gt. 0.d0) then
          do i=1,n
            work(i) = scale(i)
            work(istptr+i-1) = scale(i)
          enddo
        else
          do i=1,n
            work(i) = scl
            work(istptr+i-1) = scl
          enddo
        end if
cjch-end  replace isis_dcopy calls with explicit loop
        do 30 i = 1,n
          iwork(i) = i
   30   continue
        nfe = 0
        nfxe = 1
        if (irepl .eq. 0) then
          fbonus = 0.d0
        else if (minf) then
          fbonus = bnsfac(ifxsw,1)*bonus
        else
          fbonus = bnsfac(ifxsw,2)*bonus
        end if
        if (nfstop .eq. 0) then
          sfstop = 0.d0
        else if (minf) then
          sfstop = fstop
        else
          sfstop = -fstop
        end if
        ftest = 0.d0
        cmode = .false.
        new = .true.
        initx = .true.
        call isis_evalf (f,0,iwork,dum,n,x,sfx,nfe)
        initx = .false.
      else
c
c       continuation of previous call
c
        if (iflag .eq. 2) then
          if (minf) then
            sfstop = fstop
          else
            sfstop = -fstop
          end if
          cmode = .true.
          go to 70
        else if (iflag .eq. -1) then
          cmode = .true.
          go to 70
        else if (iflag .eq. 0) then
          cmode = .false.
          go to 90
        else
          return
        end if
      end if
c
c     subplex loop
c
   40 continue
        do 50 i = 1,n
          work(i) = abs(work(i))
   50   continue
        call isis_sortd (n,work,iwork)
        call isis_partx (n,iwork,work,nsubs,iwork(insptr))
cjch-start replace isis_dcopy calls with explicit loop
cjch        call isis_dcopy (n,x,1,work,1)
        do i=1,n
          work(i) = x(i)
        enddo
cjch-end  replace isis_dcopy calls with explicit loop
        ins = insptr
        insfnl = insptr+nsubs-1
        ipptr = 1
c
c       simplex loop
c
   60   continue
          ns = iwork(ins)
   70     continue
          call isis_simplx (f,n,work(istptr),ns,iwork(ipptr),
     *                 maxnfe,cmode,x,sfx,nfe,work(isptr),
     *                 work(ifsptr),iflag)
          cmode = .false.
          if (iflag .ne. 0) go to 110
          if (ins .lt. insfnl) then
            ins = ins+1
            ipptr = ipptr+ns
            go to 60
          end if
c
c       end simplex loop
c
        do 80 i = 1,n
          work(i) = x(i)-work(i)
   80   continue
c
c       check termination
c
   90   continue
        istep = istptr
        do 100 i = 1,n
          if (max(abs(work(i)),abs(work(istep))*psi)/
     *        max(abs(x(i)),1.d0) .gt. tol) then
            call isis_setstp (nsubs,n,work,work(istptr))
            go to 40
          end if
          istep = istep+1
  100   continue
c
c     end subplex loop
c
      iflag = 0
  110 continue
      if (minf) then
        fx = sfx
      else
        fx = -sfx
      end if
      return
c
c     invalid input
c
  120 continue
      iflag = -2
      return
      end
      subroutine isis_calcc (ns,s,ih,inew,updatc,c)
c
      integer ns,ih,inew
      double precision s(ns,ns+3),c(ns)
      logical updatc
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c calcc calculates the centroid of the simplex without the
c vertex with highest function value.
c
c input
c
c   ns     - subspace dimension
c
c   s      - double precision work space of dimension .ge.
c            ns*(ns+3) used to store simplex
c
c   ih     - index to vertex with highest function value
c
c   inew   - index to new point
c
c   updatc - logical switch
c            = .true.  : update centroid
c            = .false. : calculate centroid from scratch
c
c   c      - centroid of the simplex without vertex with
c            highest function value
c
c output
c
c   c      - new centroid
c
c local variables
c
      integer i,j
c
c subroutines and functions
c
c   blas
      external isis_daxpy,isis_dcopy,isis_dscal
c
c-----------------------------------------------------------
c
      if (updatc) then
        if (ih .eq. inew) return
        do 10 i = 1,ns
          c(i) = c(i)+(s(i,inew)-s(i,ih))/ns
   10   continue
      else
cjch-start  replace isis_dcopy calls with explicit loop
cjch        call isis_dcopy (ns,0.d0,0,c,1)
        do i=1,ns
          c(i) = 0.d0
        enddo
cjch-end  replace isis_dcopy calls with explicit loop
        do 20 j = 1,ns+1
          if (j .ne. ih) call isis_daxpy (ns,1.d0,s(1,j),1,c,1)
   20   continue
        call isis_dscal (ns,1.d0/ns,c,1)
      end if
      return
      end
      double precision function isis_dasum(n,dx,incx)
c
c     takes the sum of the absolute values.
c     uses unrolled loops for increment equal to one.
c     jack dongarra, linpack, 3/11/78.
c     modified to correct problem with negative increment, 8/21/90.
c
cjch      double precision dx(1),dtemp
      double precision dx(*),dtemp
      integer i,incx,ix,m,mp1,n
c
      isis_dasum = 0.0d0
      dtemp = 0.0d0
      if(n.le.0)return
      if(incx.eq.1)go to 20
c
c        code for increment not equal to 1
c
      ix = 1
      if(incx.lt.0)ix = (-n+1)*incx + 1
      do 10 i = 1,n
        dtemp = dtemp + dabs(dx(ix))
        ix = ix + incx
   10 continue
      isis_dasum = dtemp
      return
c
c        code for increment equal to 1
c
c
c        clean-up loop
c
   20 m = mod(n,6)
      if( m .eq. 0 ) go to 40
      do 30 i = 1,m
        dtemp = dtemp + dabs(dx(i))
   30 continue
      if( n .lt. 6 ) go to 60
   40 mp1 = m + 1
      do 50 i = mp1,n,6
        dtemp = dtemp + dabs(dx(i)) + dabs(dx(i + 1)) + dabs(dx(i + 2))
     *  + dabs(dx(i + 3)) + dabs(dx(i + 4)) + dabs(dx(i + 5))
   50 continue
   60 isis_dasum = dtemp
      return
      end
      subroutine isis_daxpy(n,da,dx,incx,dy,incy)
c
c     constant times a vector plus a vector.
c     uses unrolled loops for increments equal to one.
c     jack dongarra, linpack, 3/11/78.
c
cjch      double precision dx(1),dy(1),da
      double precision dx(*),dy(*),da
      integer i,incx,incy,ix,iy,m,mp1,n
c
      if(n.le.0)return
      if (da .eq. 0.0d0) return
      if(incx.eq.1.and.incy.eq.1)go to 20
c
c        code for unequal increments or equal increments
c          not equal to 1
c
      ix = 1
      iy = 1
      if(incx.lt.0)ix = (-n+1)*incx + 1
      if(incy.lt.0)iy = (-n+1)*incy + 1
      do 10 i = 1,n
        dy(iy) = dy(iy) + da*dx(ix)
        ix = ix + incx
        iy = iy + incy
   10 continue
      return
c
c        code for both increments equal to 1
c
c
c        clean-up loop
c
   20 m = mod(n,4)
      if( m .eq. 0 ) go to 40
      do 30 i = 1,m
        dy(i) = dy(i) + da*dx(i)
   30 continue
      if( n .lt. 4 ) return
   40 mp1 = m + 1
      do 50 i = mp1,n,4
        dy(i) = dy(i) + da*dx(i)
        dy(i + 1) = dy(i + 1) + da*dx(i + 1)
        dy(i + 2) = dy(i + 2) + da*dx(i + 2)
        dy(i + 3) = dy(i + 3) + da*dx(i + 3)
   50 continue
      return
      end
      subroutine isis_dcopy(n,dx,incx,dy,incy)
c
c     copies a vector, x, to a vector, y.
c     uses unrolled loops for increments equal to one.
c     jack dongarra, linpack, 3/11/78.
c
cjch      double precision dx(1),dy(1)
      double precision dx(*),dy(*)
      integer i,incx,incy,ix,iy,m,mp1,n
c
      if(n.le.0)return
      if(incx.eq.1.and.incy.eq.1)go to 20
c
c        code for unequal increments or equal increments
c          not equal to 1
c
      ix = 1
      iy = 1
      if(incx.lt.0)ix = (-n+1)*incx + 1
      if(incy.lt.0)iy = (-n+1)*incy + 1
      do 10 i = 1,n
        dy(iy) = dx(ix)
        ix = ix + incx
        iy = iy + incy
   10 continue
      return
c
c        code for both increments equal to 1
c
c
c        clean-up loop
c
   20 m = mod(n,7)
      if( m .eq. 0 ) go to 40
      do 30 i = 1,m
        dy(i) = dx(i)
   30 continue
      if( n .lt. 7 ) return
   40 mp1 = m + 1
      do 50 i = mp1,n,7
        dy(i) = dx(i)
        dy(i + 1) = dx(i + 1)
        dy(i + 2) = dx(i + 2)
        dy(i + 3) = dx(i + 3)
        dy(i + 4) = dx(i + 4)
        dy(i + 5) = dx(i + 5)
        dy(i + 6) = dx(i + 6)
   50 continue
      return
      end
      double precision function isis_dist (n,x,y)
c
      integer n
      double precision x(n),y(n)
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c dist calculates the distance between the points x,y.
c
c input
c
c   n      - number of components
c
c   x      - point in n-space
c
c   y      - point in n-space
c
c local variables
c
      integer i
      double precision absxmy,scale,sum
c
c subroutines and functions
c
c   fortran
      intrinsic abs,sqrt
c
c-----------------------------------------------------------
c
      absxmy = abs(x(1)-y(1))
      if (absxmy .le. 1.d0) then
        sum = absxmy*absxmy
        scale = 1.d0
      else
        sum = 1.d0
        scale = absxmy
      end if
      do 10 i = 2,n
        absxmy = abs(x(i)-y(i))
        if (absxmy .le. scale) then
          sum = sum+(absxmy/scale)**2
        else
          sum = 1.d0+sum*(scale/absxmy)**2
          scale = absxmy
        end if
   10 continue
      isis_dist = scale*sqrt(sum)
      return
      end
      subroutine isis_dscal(n,da,dx,incx)
c
c     scales a vector by a constant.
c     uses unrolled loops for increment equal to one.
c     jack dongarra, linpack, 3/11/78.
c     modified to correct problem with negative increment, 8/21/90.
c
cjch      double precision da,dx(1)
      double precision da,dx(*)
      integer i,incx,ix,m,mp1,n
c
      if(n.le.0)return
      if(incx.eq.1)go to 20
c
c        code for increment not equal to 1
c
      ix = 1
      if(incx.lt.0)ix = (-n+1)*incx + 1
      do 10 i = 1,n
        dx(ix) = da*dx(ix)
        ix = ix + incx
   10 continue
      return
c
c        code for increment equal to 1
c
c
c        clean-up loop
c
   20 m = mod(n,5)
      if( m .eq. 0 ) go to 40
      do 30 i = 1,m
        dx(i) = da*dx(i)
   30 continue
      if( n .lt. 5 ) return
   40 mp1 = m + 1
      do 50 i = mp1,n,5
        dx(i) = da*dx(i)
        dx(i + 1) = da*dx(i + 1)
        dx(i + 2) = da*dx(i + 2)
        dx(i + 3) = da*dx(i + 3)
        dx(i + 4) = da*dx(i + 4)
   50 continue
      return
      end
      subroutine isis_evalf (f,ns,ips,xs,n,x,sfx,nfe)
c
      integer ns,n,nfe
      integer ips(*)
      double precision f,xs(*),x(n),sfx
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c evalf evaluates the function f at a point defined by x
c with ns of its components replaced by those in xs.
c
c input
c
c   f      - user supplied function f(n,x) to be optimized
c
c   ns     - subspace dimension
c
c   ips    - permutation vector
c
c   xs     - double precision ns-vector to be mapped to x
c
c   n      - problem dimension
c
c   x      - double precision n-vector
c
c   nfe    - number of function evaluations
c
c output
c
c   sfx    - signed value of f evaluated at x
c
c   nfe    - incremented number of function evaluations
c
c common
c
      integer nsmin,nsmax,irepl,ifxsw,nfstop,nfxe
      double precision alpha,beta,gamma,delta,psi,omega,
     *     bonus,fstop,fxstat,ftest
      logical minf,initx,newx
c
      common /usubc/ alpha,beta,gamma,delta,psi,omega,nsmin,
     *               nsmax,irepl,ifxsw,bonus,fstop,nfstop,
     *               nfxe,fxstat(4),ftest,minf,initx,newx
c
      double precision fbonus,sfstop,sfbest
      logical new
c
      common /isubc/ fbonus,sfstop,sfbest,new
c
c local variables
c
      integer i
      double precision fx
      logical newbst
c
      save
c
c subroutines and functions
c
      external f,isis_fstats
c
c-----------------------------------------------------------
c
      do 10 i = 1,ns
        x(ips(i)) = xs(i)
   10 continue
      newx = new .or. irepl .ne. 2
      fx = f(n,x)
      if (irepl .eq. 0) then
        if (minf) then
          sfx = fx
        else
          sfx = -fx
        end if
      else if (new) then
        if (minf) then
          sfx = fx
          newbst = fx .lt. ftest
        else
          sfx = -fx
          newbst = fx .gt. ftest
        end if
        if (initx .or. newbst) then
          if (irepl .eq. 1) call isis_fstats (fx,1,.true.)
          ftest = fx
          sfbest = sfx
        end if
      else
        if (irepl .eq. 1) then
          call isis_fstats (fx,1,.false.)
          fx = fxstat(ifxsw)
        end if
        ftest = fx+fbonus*fxstat(4)
        if (minf) then
          sfx = ftest
          sfbest = fx
        else
          sfx = -ftest
          sfbest = -fx
        end if
      end if
      nfe = nfe+1
      return
      end
      subroutine isis_fstats (fx,ifxwt,reset)
c
      integer ifxwt
      double precision fx
      logical reset
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c fstats modifies the common /usubc/ variables nfxe,fxstat.
c
c input
c
c   fx     - most recent evaluation of f at best x
c
c   ifxwt  - integer weight for fx
c
c   reset  - logical switch
c            = .true.  : initialize nfxe,fxstat
c            = .false. : update nfxe,fxstat
c
c common
c
      integer nsmin,nsmax,irepl,ifxsw,nfstop,nfxe
      double precision alpha,beta,gamma,delta,psi,omega,
     *     bonus,fstop,fxstat,ftest
      logical minf,initx,newx
c
      common /usubc/ alpha,beta,gamma,delta,psi,omega,nsmin,
     *               nsmax,irepl,ifxsw,bonus,fstop,nfstop,
     *               nfxe,fxstat(4),ftest,minf,initx,newx
c
c local variables
c
      integer nsv
      double precision fscale,f1sv
c
      save
c
c subroutines and functions
c
c   fortran
      intrinsic abs,max,min,sqrt
c
c-----------------------------------------------------------
c
      if (reset) then
        nfxe = ifxwt
        fxstat(1) = fx
        fxstat(2) = fx
        fxstat(3) = fx
        fxstat(4) = 0.d0
      else
        nsv = nfxe
        f1sv = fxstat(1)
        nfxe = nfxe+ifxwt
        fxstat(1) = fxstat(1)+ifxwt*(fx-fxstat(1))/nfxe
        fxstat(2) = max(fxstat(2),fx)
        fxstat(3) = min(fxstat(3),fx)
        fscale = max(abs(fxstat(2)),abs(fxstat(3)),1.d0)
        fxstat(4) = fscale*sqrt((
     *              (nsv-1)*(fxstat(4)/fscale)**2+
     *              nsv*((fxstat(1)-f1sv)/fscale)**2+
     *              ifxwt*((fx-fxstat(1))/fscale)**2)
     *              /(nfxe-1))
      end if
      return
      end
      subroutine isis_newpt (ns,coef,xbase,xold,new,xnew,small)
c
      integer ns
      double precision coef,xbase(ns),xold(ns),xnew(*)
      logical new,small
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c newpt performs reflections, expansions, contractions, and
c shrinkages (massive contractions) by computing:
c
c xbase + coef * (xbase - xold)
c
c The result is stored in xnew if new .eq. .true.,
c in xold otherwise.
c
c use :  coef .gt. 0 to reflect
c        coef .lt. 0 to expand, contract, or shrink
c
c input
c
c   ns     - number of components (subspace dimension)
c
c   coef   - one of four simplex method coefficients
c
c   xbase  - double precision ns-vector representing base
c            point
c
c   xold   - double precision ns-vector representing old
c            point
c
c   new    - logical switch
c            = .true.  : store result in xnew
c            = .false. : store result in xold, xnew is not
c                        referenced
c
c output
c
c   xold   - unchanged if new .eq. .true., contains new
c            point otherwise
c
c   xnew   - double precision ns-vector representing new
c            point if  new .eq. .true., not referenced
c            otherwise
c
c   small  - logical flag
c            = .true.  : coincident points
c            = .false. : otherwise
c
c local variables
c
      integer i
      double precision xoldi
      logical eqbase,eqold
c
c subroutines and functions
c
c   fortran
      intrinsic dble
c
c-----------------------------------------------------------
c
      eqbase = .true.
      eqold = .true.
      if (new) then
        do 10 i = 1,ns
          xnew(i) = xbase(i)+coef*(xbase(i)-xold(i))
          eqbase = eqbase .and.
     *             (dble(xnew(i)) .eq. dble(xbase(i)))
          eqold = eqold .and.
     *            (dble(xnew(i)) .eq. dble(xold(i)))
   10   continue
      else
        do 20 i = 1,ns
          xoldi = xold(i)
          xold(i) = xbase(i)+coef*(xbase(i)-xold(i))
          eqbase = eqbase .and.
     *             (dble(xold(i)) .eq. dble(xbase(i)))
          eqold = eqold .and.
     *            (dble(xold(i)) .eq. dble(xoldi))
   20   continue
      end if
      small = eqbase .or. eqold
      return
      end
      subroutine isis_order (npts,fs,il,is,ih)
c
      integer npts,il,is,ih
      double precision fs(npts)
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c order determines the indices of the vertices with the
c lowest, second highest, and highest function values.
c
c input
c
c   npts   - number of points in simplex
c
c   fs     - double precision vector of function values of
c            simplex
c
c   il     - index to vertex with lowest function value
c
c output
c
c   il     - new index to vertex with lowest function value
c
c   is     - new index to vertex with second highest
c            function value
c
c   ih     - new index to vertex with highest function value
c
c local variables
c
      integer i,il0,j
c
c subroutines and functions
c
c   fortran
      intrinsic mod
c
c-----------------------------------------------------------
c
      il0 = il
      j = mod(il0,npts)+1
      if (fs(j) .ge. fs(il)) then
        ih = j
        is = il0
      else
        ih = il0
        is = j
        il = j
      end if
      do 10 i = il0+1,il0+npts-2
        j = mod(i,npts)+1
        if (fs(j) .ge. fs(ih)) then
          is = ih
          ih = j
        else if (fs(j) .gt. fs(is)) then
          is = j
        else if (fs(j) .lt. fs(il)) then
          il = j
        end if
   10 continue
      return
      end
      subroutine isis_partx (n,ip,absdx,nsubs,nsvals)
c
      integer n,nsubs,nsvals(*)
      integer ip(n)
      double precision absdx(n)
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c partx partitions the vector x by grouping components of
c similar magnitude of change.
c
c input
c
c   n      - number of components (problem dimension)
c
c   ip     - permutation vector
c
c   absdx  - vector of magnitude of change in x
c
c   nsvals - integer array dimensioned .ge. int(n/nsmin)
c
c output
c
c   nsubs  - number of subspaces
c
c   nsvals - integer array of subspace dimensions
c
c common
c
      integer nsmin,nsmax,irepl,ifxsw,nfstop,nfxe
      double precision alpha,beta,gamma,delta,psi,omega,
     *     bonus,fstop,fxstat,ftest
      logical minf,initx,newx
c
      common /usubc/ alpha,beta,gamma,delta,psi,omega,nsmin,
     *               nsmax,irepl,ifxsw,bonus,fstop,nfstop,
     *               nfxe,fxstat(4),ftest,minf,initx,newx
c
c local variables
c
      integer i,nleft,ns1,ns2,nused
      double precision asleft,as1,as1max,as2,gap,gapmax
c
      save
c
c subroutines and functions
c
c   fortran
      intrinsic min
c
c-----------------------------------------------------------
c
      nsubs = 0
      nused = 0
      nleft = n
      asleft = absdx(1)
      do 10 i = 2,n
        asleft = asleft+absdx(i)
   10 continue
   20 continue
      if (nused .lt. n) then
        nsubs = nsubs+1
        as1 = 0.d0
        do 30 i = 1,nsmin-1
          as1 = as1+absdx(ip(nused+i))
   30   continue
        gapmax = -1.d0
        do 40 ns1 = nsmin,min(nsmax,nleft)
          as1 = as1+absdx(ip(nused+ns1))
          ns2 = nleft-ns1
          if (ns2 .gt. 0) then
            if (ns2 .ge. ((ns2-1)/nsmax+1)*nsmin) then
              as2 = asleft-as1
              gap = as1/ns1-as2/ns2
              if (gap .gt. gapmax) then
                gapmax = gap
                nsvals(nsubs) = ns1
                as1max = as1
              end if
            end if
          else
            if (as1/ns1 .gt. gapmax) then
              nsvals(nsubs) = ns1
              return
            end if
          end if
   40   continue
        nused = nused+nsvals(nsubs)
        nleft = n-nused
        asleft = asleft-as1max
        go to 20
      end if
      return
      end
      subroutine isis_setstp (nsubs,n,deltax,step)
c
      integer nsubs,n
      double precision deltax(n),step(n)
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c setstp sets the stepsizes for the corresponding components
c of the solution vector.
c
c input
c
c   nsubs  - number of subspaces
c
c   n      - number of components (problem dimension)
c
c   deltax - vector of change in solution vector
c
c   step   - stepsizes for corresponding components of
c            solution vector
c
c output
c
c   step   - new stepsizes
c
c common
c
      integer nsmin,nsmax,irepl,ifxsw,nfstop,nfxe
      double precision alpha,beta,gamma,delta,psi,omega,
     *     bonus,fstop,fxstat,ftest
      logical minf,initx,newx
c
      common /usubc/ alpha,beta,gamma,delta,psi,omega,nsmin,
     *               nsmax,irepl,ifxsw,bonus,fstop,nfstop,
     *               nfxe,fxstat(4),ftest,minf,initx,newx
c
c local variables
c
      integer i
      double precision isis_dasum,stpfac
c
      save
c
c subroutines and functions
c
c   blas
      external isis_dasum,isis_dscal
c   fortran
      intrinsic max,min,sign
c
c-----------------------------------------------------------
c
c     set new step
c
      if (nsubs .gt. 1) then
        stpfac = min(max(isis_dasum(n,deltax,1)/isis_dasum(n,step,1),
     *           omega),1.d0/omega)
      else
        stpfac = psi
      end if
      call isis_dscal (n,stpfac,step,1)
c
c     reorient simplex
c
      do 10 i = 1,n
        if (deltax(i) .ne. 0.) then
          step(i) = sign(step(i),deltax(i))
        else
          step(i) = -step(i)
        end if
   10 continue
      return
      end
      subroutine isis_simplx (f,n,step,ns,ips,maxnfe,cmode,x,fx,
     &                   nfe,s,fs,iflag)
c
      integer n,ns,maxnfe,nfe,iflag
      integer ips(ns)
      double precision f,step(n),x(n),fx,s(ns,ns+3),fs(ns+1)
      logical cmode
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c simplx uses the Nelder-Mead simplex method to minimize the
c function f on a subspace.
c
c input
c
c   f      - function to be minimized, declared external in
c            calling routine
c
c   n      - problem dimension
c
c   step   - stepsizes for corresponding components of x
c
c   ns     - subspace dimension
c
c   ips    - permutation vector
c
c   maxnfe - maximum number of function evaluations
c
c   cmode  - logical switch
c            = .true.  : continuation of previous call
c            = .false. : first call
c
c   x      - starting guess for minimum
c
c   fx     - value of f at x
c
c   nfe    - number of function evaluations
c
c   s      - double precision work array of dimension .ge.
c            ns*(ns+3) used to store simplex
c
c   fs     - double precision work array of dimension .ge.
c            ns+1 used to store function values of simplex
c            vertices
c
c output
c
c   x      - computed minimum
c
c   fx     - value of f at x
c
c   nfe    - incremented number of function evaluations
c
c   iflag  - error flag
c            = -1 : maxnfe exceeded
c            =  0 : simplex reduced by factor of psi
c            =  1 : limit of machine precision
c            =  2 : reached fstop
c
c common
c
      integer nsmin,nsmax,irepl,ifxsw,nfstop,nfxe
      double precision alpha,beta,gamma,delta,psi,omega,
     *     bonus,fstop,fxstat,ftest
      logical minf,initx,newx
c
      common /usubc/ alpha,beta,gamma,delta,psi,omega,nsmin,
     *               nsmax,irepl,ifxsw,bonus,fstop,nfstop,
     *               nfxe,fxstat(4),ftest,minf,initx,newx
c
      double precision fbonus,sfstop,sfbest
      logical new
c
      common /isubc/ fbonus,sfstop,sfbest,new
c
c local variables
c
      integer i,icent,ih,il,inew,is,itemp,j,npts
      double precision isis_dist,dum(1),fc,fe,fr,tol
      logical small,updatc
c
      save
c
c subroutines and functions
c
      external f,isis_calcc,isis_dist,isis_evalf,isis_newpt
      external isis_order,isis_start
c   blas
      external isis_dcopy
c   fortran
      intrinsic min
c
c-----------------------------------------------------------
c
      if (cmode) go to 50
      npts = ns+1
      icent = ns+2
      itemp = ns+3
      updatc = .false.
      call isis_start (n,x,step,ns,ips,s,small)
      if (small) then
        iflag = 1
        return
      end if
      if (irepl .gt. 0) then
        new = .false.
        call isis_evalf (f,ns,ips,s(1,1),n,x,fs(1),nfe)
      else
        fs(1) = fx
      end if
      new = .true.
      do 10 j = 2,npts
        call isis_evalf (f,ns,ips,s(1,j),n,x,fs(j),nfe)
   10 continue
      il = 1
      call isis_order (npts,fs,il,is,ih)
      tol = psi*isis_dist(ns,s(1,ih),s(1,il))
c
c     main loop
c
   20 continue
        call isis_calcc (ns,s,ih,inew,updatc,s(1,icent))
        updatc = .true.
        inew = ih
c
c       reflect
c
        call isis_newpt (ns,alpha,s(1,icent),s(1,ih),.true.,
     *              s(1,itemp),small)
        if (small) go to 40
        call isis_evalf (f,ns,ips,s(1,itemp),n,x,fr,nfe)
        if (fr .lt. fs(il)) then
c
c         expand
c
          call isis_newpt (ns,-gamma,s(1,icent),s(1,itemp),
     *                .true.,s(1,ih),small)
          if (small) go to 40
          call isis_evalf (f,ns,ips,s(1,ih),n,x,fe,nfe)
          if (fe .lt. fr) then
            fs(ih) = fe
          else
            call isis_dcopy (ns,s(1,itemp),1,s(1,ih),1)
            fs(ih) = fr
          end if
        else if (fr .lt. fs(is)) then
c
c         accept reflected point
c
          call isis_dcopy (ns,s(1,itemp),1,s(1,ih),1)
          fs(ih) = fr
        else
c
c         contract
c
          if (fr .gt. fs(ih)) then
            call isis_newpt (ns,-beta,s(1,icent),s(1,ih),.true.,
     *                  s(1,itemp),small)
          else
            call isis_newpt (ns,-beta,s(1,icent),s(1,itemp),
     *                  .false.,dum,small)
          end if
          if (small) go to 40
          call isis_evalf (f,ns,ips,s(1,itemp),n,x,fc,nfe)
          if (fc .lt. min(fr,fs(ih))) then
            call isis_dcopy (ns,s(1,itemp),1,s(1,ih),1)
            fs(ih) = fc
          else
c
c           shrink simplex
c
            do 30 j = 1,npts
              if (j .ne. il) then
                call isis_newpt (ns,-delta,s(1,il),s(1,j),
     *                      .false.,dum,small)
                if (small) go to 40
                call isis_evalf (f,ns,ips,s(1,j),n,x,fs(j),nfe)
              end if
   30       continue
          end if
          updatc = .false.
        end if
        call isis_order (npts,fs,il,is,ih)
c
c       check termination
c
   40   continue
        if (irepl .eq. 0) then
          fx = fs(il)
        else
          fx = sfbest
        end if
   50   continue
        if (nfstop .gt. 0 .and. fx .le. sfstop .and.
     *      nfxe .ge. nfstop) then
          iflag = 2
        else if (nfe .ge. maxnfe) then
          iflag = -1
        else if (isis_dist(ns,s(1,ih),s(1,il)) .le. tol .or.
     *           small) then
          iflag = 0
        else
          go to 20
        end if
c
c     end main loop, return best point
c
      do 60 i = 1,ns
        x(ips(i)) = s(i,il)
   60 continue
      return
      end
      subroutine isis_sortd (n,xkey,ix)
c
      integer n
      integer ix(n)
      double precision xkey(n)
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c sortd uses the shakersort method to sort an array of keys
c in decreasing order. The sort is performed implicitly by
c modifying a vector of indices.
c
c For nearly sorted arrays, sortd requires O(n) comparisons.
c for completely unsorted arrays, sortd requires O(n**2)
c comparisons and will be inefficient unless n is small.
c
c input
c
c   n      - number of components
c
c   xkey   - double precision vector of keys
c
c   ix     - integer vector of indices
c
c output
c
c   ix     - indices satisfy xkey(ix(i)) .ge. xkey(ix(i+1))
c            for i = 1,...,n-1
c
c local variables
c
      integer i,ifirst,ilast,iswap,ixi,ixip1
c
c-----------------------------------------------------------
c
      ifirst = 1
      iswap = 1
      ilast = n-1
   10 continue
      if (ifirst .le. ilast) then
        do 20 i = ifirst,ilast
          ixi = ix(i)
          ixip1 = ix(i+1)
          if (xkey(ixi) .lt. xkey(ixip1)) then
            ix(i) = ixip1
            ix(i+1) = ixi
            iswap = i
          end if
   20   continue
        ilast = iswap-1
        do 30 i = ilast,ifirst,-1
          ixi = ix(i)
          ixip1 = ix(i+1)
          if (xkey(ixi) .lt. xkey(ixip1)) then
            ix(i) = ixip1
            ix(i+1) = ixi
            iswap = i
          end if
   30   continue
        ifirst = iswap+1
        go to 10
      end if
      return
      end
      subroutine isis_start (n,x,step,ns,ips,s,small)
c
      integer n,ns
      integer ips(n)
      double precision x(n),step(n),s(ns,ns+3)
      logical small
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c start creates the initial simplex for simplx minimization.
c
c input
c
c   n      - problem dimension
c
c   x      - current best point
c
c   step   - stepsizes for corresponding components of x
c
c   ns     - subspace dimension
c
c   ips    - permutation vector
c
c
c output
c
c   s      - first ns+1 columns contain initial simplex
c
c   small  - logical flag
c            = .true.  : coincident points
c            = .false. : otherwise
c
c local variables
c
      integer i,j
c
c subroutines and functions
c
c   blas
      external isis_dcopy
c   fortran
      intrinsic dble
c
c-----------------------------------------------------------
c
      do 10 i = 1,ns
        s(i,1) = x(ips(i))
   10 continue
      do 20 j = 2,ns+1
        call isis_dcopy (ns,s(1,1),1,s(1,j),1)
        s(j-1,j) = s(j-1,1)+step(ips(j-1))
   20 continue
c
c check for coincident points
c
      do 30 j = 2,ns+1
        if (dble(s(j-1,j)) .eq. dble(s(j-1,1))) go to 40
   30 continue
      small = .false.
      return
c
c coincident points
c
   40 continue
      small = .true.
      return
      end
      subroutine isis_subopt (n)
c
      integer n
c
c                                         Coded by Tom Rowan
c                            Department of Computer Sciences
c                              University of Texas at Austin
c
c subopt sets options for subplx.
c
c input
c
c   n      - problem dimension
c
c common
c
      integer nsmin,nsmax,irepl,ifxsw,nfstop,nfxe
      double precision alpha,beta,gamma,delta,psi,omega,
     *     bonus,fstop,fxstat,ftest
      logical minf,initx,newx
c
      common /usubc/ alpha,beta,gamma,delta,psi,omega,nsmin,
     *               nsmax,irepl,ifxsw,bonus,fstop,nfstop,
     *               nfxe,fxstat(4),ftest,minf,initx,newx
c
      save
c
c subroutines and functions
c
c   fortran
      intrinsic min
c
c-----------------------------------------------------------
c
c***********************************************************
c simplex method strategy parameters
c***********************************************************
c
c alpha  - reflection coefficient
c          alpha .gt. 0
c
      alpha = 1.d0
c
c beta   - contraction coefficient
c          0 .lt. beta .lt. 1
c
      beta = .5d0
c
c gamma  - expansion coefficient
c          gamma .gt. 1
c
      gamma = 2.d0
c
c delta  - shrinkage (massive contraction) coefficient
c          0 .lt. delta .lt. 1
c
      delta = .5d0
c
c***********************************************************
c subplex method strategy parameters
c***********************************************************
c
c psi    - simplex reduction coefficient
c          0 .lt. psi .lt. 1
c
      psi = .25d0
c
c omega  - step reduction coefficient
c          0 .lt. omega .lt. 1
c
      omega = .1d0
c
c nsmin and nsmax specify a range of subspace dimensions.
c In addition to satisfying  1 .le. nsmin .le. nsmax .le. n,
c nsmin and nsmax must be chosen so that n can be expressed
c as a sum of positive integers where each of these integers
c ns(i) satisfies   nsmin .le. ns(i) .ge. nsmax.
c Specifically,
c     nsmin*ceil(n/nsmax) .le. n   must be true.
c
c nsmin  - subspace dimension minimum
c
      nsmin = min(2,n)
c
c nsmax  - subspace dimension maximum
c
      nsmax = min(5,n)
c
c***********************************************************
c subplex method special cases
c***********************************************************
c nelder-mead simplex method with periodic restarts
c   nsmin = nsmax = n
c***********************************************************
c nelder-mead simplex method
c   nsmin = nsmax = n, psi = small positive
c***********************************************************
c
c irepl, ifxsw, and bonus deal with measurement replication.
c Objective functions subject to large amounts of noise can
c cause an optimization method to halt at a false optimum.
c An expensive solution to this problem is to evaluate f
c several times at each point and return the average (or max
c or min) of these trials as the function value.  subplx
c performs measurement replication only at the current best
c point. The longer a point is retained as best, the more
c accurate its function value becomes.
c
c The common variable nfxe contains the number of function
c evaluations at the current best point. fxstat contains the
c mean, max, min, and standard deviation of these trials.
c
c irepl  - measurement replication switch
c irepl  = 0, 1, or 2
c        = 0 : no measurement replication
c        = 1 : subplx performs measurement replication
c        = 2 : user performs measurement replication
c              (This is useful when optimizing on the mean,
c              max, or min of trials is insufficient. Common
c              variable initx is true for first function
c              evaluation. newx is true for first trial at
c              this point. The user uses subroutine fstats
c              within his objective function to maintain
c              fxstat. By monitoring newx, the user can tell
c              whether to return the function evaluation
c              (newx = .true.) or to use the new function
c              evaluation to refine the function evaluation
c              of the current best point (newx = .false.).
c              The common variable ftest gives the function
c              value that a new point must beat to be
c              considered the new best point.)
c
      irepl = 0
c
c ifxsw  - measurement replication optimization switch
c ifxsw  = 1, 2, or 3
c        = 1 : retain mean of trials as best function value
c        = 2 : retain max
c        = 3 : retain min
c
      ifxsw = 1
c
c Since the current best point will also be the most
c accurately evaluated point whenever irepl .gt. 0, a bonus
c should be added to the function value of the best point
c so that the best point is not replaced by a new point
c that only appears better because of noise.
c subplx uses bonus to determine how many multiples of
c fxstat(4) should be added as a bonus to the function
c evaluation. (The bonus is adjusted automatically by
c subplx when ifxsw or minf is changed.)
c
c bonus  - measurement replication bonus coefficient
c          bonus .ge. 0 (normally, bonus = 0 or 1)
c        = 0 : bonus not used
c        = 1 : bonus used
c
      bonus = 1.d0
c
c nfstop = 0 : f(x) is not tested against fstop
c        = 1 : if f(x) has reached fstop, subplx returns
c              iflag = 2
c        = 2 : (only valid when irepl .gt. 0)
c              if f(x) has reached fstop and
c              nfxe .gt. nfstop, subplx returns iflag = 2
c
      nfstop = 0
c
c fstop  - f target value
c          Its usage is determined by the value of nfstop.
c
c minf   - logical switch
c        = .true.  : subplx performs minimization
c        = .false. : subplx performs maximization
c
      minf = .true.
      return
      end

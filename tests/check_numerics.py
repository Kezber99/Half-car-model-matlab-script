"""Independent SciPy cross-check of the MATLAB equations, not a MATLAB test.
Run: python tests/check_numerics.py (requires numpy and scipy).
Reads the actual MATLAB parameter assignments and M/K/C_damping/F literals.
"""
from pathlib import Path
import re
import numpy as np
from scipy.signal import StateSpace, lsim
from scipy.integrate import solve_ivp, trapezoid

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'half_car_model.m').read_text()
P = {}
for name in ['m','m1','m2','Iy','a1','a2','k1','k2','kt1','kt2','c1','c2',
             'vel','simulation_dt','post_bump_time','convergence_relative_tolerance']:
    expression = re.search(r'^'+name+r'\s*=\s*([^;]+);', SOURCE, re.M)[1]
    assert re.fullmatch(r'[\d.eE+*/()\s-]+', expression), expression
    P[name] = eval(expression, {'__builtins__': {}}, {})

def matrix(name):
    literal = re.search(r'^'+name+r'\s*=\s*\[(.*?)\];', SOURCE, re.M | re.S)[1]
    rows = []
    for row in literal.split(';'):
        cells = row.split()
        if cells:
            assert all(re.fullmatch(r'[\w+*/().^-]+', c) for c in cells)
            rows.append([eval(c.replace('^','**'), {'__builtins__': {}}, P) for c in cells])
    return np.array(rows, dtype=float)

M, K, C, F = (matrix(n) for n in ['M','K','C_damping','F'])
front = np.array([1, -P['a1'], -1, 0])
rear = np.array([1, P['a2'], 0, -1])
# Independent force/energy construction checks signs, not just symmetry.
np.testing.assert_allclose(K, P['k1']*np.outer(front,front) +
    P['k2']*np.outer(rear,rear) + np.diag([0,0,P['kt1'],P['kt2']]))
np.testing.assert_allclose(C, P['c1']*np.outer(front,front) + P['c2']*np.outer(rear,rear))
A = np.block([[np.zeros((4,4)),np.eye(4)],[-np.linalg.solve(M,K),-np.linalg.solve(M,C)]])
B = np.vstack([np.zeros((4,2)),np.linalg.solve(M,F)])
sys = StateSpace(A,B,np.eye(8),np.zeros((8,2)))
assert np.linalg.eigvals(A).real.max() < 0
static = 9.81*np.array([P['m']*P['a2']/(P['a1']+P['a2'])+P['m1'],
                        P['m']*P['a1']/(P['a1']+P['a2'])+P['m2']])
np.testing.assert_allclose(static.sum(),9.81*(P['m']+P['m1']+P['m2']))

def road(shape, heights, widths, gaps):
    xr = list(np.arange(0,5.01,.1)); zr = [0.]*len(xr)
    for i,(h,w) in enumerate(zip(heights,widths)):
        if i and gaps[i-1] > 0:
            gap = np.linspace(xr[-1],xr[-1]+gaps[i-1],max(2,int(np.ceil(gaps[i-1]/.1))+1))
            xr.extend(gap[1:]); zr.extend(np.zeros(len(gap)-1))
        phase = np.linspace(0,np.pi,315)
        if shape == 'cosine':
            fraction = np.linspace(0,1,315)
            bx = xr[-1]+w*fraction; bz = h/2*(1-np.cos(2*np.pi*fraction))
        else:
            bx = xr[-1]+w/2*(1-np.cos(phase)); bz = h*np.sin(phase)
        bz[[0,-1]]=0
        np.testing.assert_allclose(bz.max(),h,atol=1e-12)
        np.testing.assert_allclose(bx[-1]-bx[0],w,atol=1e-12)
        xr.extend(bx[1:]); zr.extend(bz[1:])
    end = max(1,xr[-1]/P['vel']+P['post_bump_time'])
    length = max(15,P['vel']*end+P['a1']+P['a2']-xr[-1])
    tail=np.linspace(xr[-1],xr[-1]+length,int(np.ceil(length/.1))+1)
    xr.extend(tail[1:]); zr.extend(np.zeros(len(tail)-1))
    assert np.min(np.diff(xr))>0
    return np.array(xr),np.array(zr),end

def simulate(xr,zr,end,steps):
    t=np.linspace(0,end,steps+1)
    u=np.c_[np.interp(P['vel']*t+P['a1']+P['a2'],xr,zr),np.interp(P['vel']*t,xr,zr)]
    _,x,_=lsim(sys,u,t)
    acc=(x@A.T+u@B.T)[:,4]
    travel=np.c_[x[:,0]-P['a1']*x[:,1]-x[:,2],x[:,0]+P['a2']*x[:,1]-x[:,3]]
    loads=static+(u-x[:,2:4])*np.array([P['kt1'],P['kt2']])
    rms=np.sqrt(trapezoid(acc**2,t)/end)
    metrics=np.r_[abs(x[:,0]).max(),abs(x[:,1]).max(),abs(acc).max(),
                  abs(travel).max(axis=0),loads.min(axis=0),rms]
    return t,u,x,acc,travel,loads,metrics

for shape in ['cosine','half_ellipse']:
    for heights,widths,gaps in [([.2],[.4],[]),([.2,.1,.15],[.4,.6,.5],[1,1.5]),([.1,.2],[.3,.7],[0])]:
        xr,zr,end=road(shape,heights,widths,gaps)
        n=int(np.ceil(end/P['simulation_dt']))
        coarse=simulate(xr,zr,end,n); fine=simulate(xr,zr,end,2*n)
        allowed=np.array([1e-5,1e-5,.01,1e-5,1e-5,1,1,.01])+P['convergence_relative_tolerance']*abs(fine[-1])
        ratio=abs(coarse[-1]-fine[-1])/allowed
        assert np.all(ratio<=1), (shape, heights, ratio)
        assert np.isfinite(coarse[2]).all()
        np.testing.assert_allclose(coarse[1][-1],[0,0],atol=1e-12)
        print(f'PASS: {shape}, {len(heights)} bumps; maximum convergence allowance used {ratio.max():.3f}')

xr,zr,end=road('cosine',[.2],[.4],[])
n=int(np.ceil(end/P['simulation_dt']))
t,u,x,acc,travel,loads,metrics=simulate(xr,zr,end,n)
# Integrate the same temporally interpolated input independently of lsim.
def derivative(tt,xx):
    uu=np.array([np.interp(tt,t,u[:,0]),np.interp(tt,t,u[:,1])])
    return A@xx+B@uu
ode=solve_ivp(derivative,(0,end),np.zeros(8),t_eval=t,rtol=1e-9,atol=1e-11,max_step=end/n/3)
assert ode.success
np.testing.assert_allclose(ode.y.T,x,rtol=1e-4,atol=2e-7)
assert loads.min()<0, 'Default severe bump should exercise the contact-validity warning.'
# Flat road must give zero dynamics, not zero total normal load.
flat=simulate(xr,np.zeros_like(zr),end,n)
np.testing.assert_array_equal(flat[2],np.zeros_like(flat[2]))
np.testing.assert_allclose(flat[5],np.tile(static,(n+1,1)))
# A uniform static elevation must satisfy the equilibrium equations.
eq=np.array([.02,0,.02,.02])
np.testing.assert_allclose(K@eq,F@np.array([.02,.02]),atol=1e-10)
# Changing rendering settings cannot enter the numerical solve.
for playback_speed in [.1,1,2]:
    frames=np.arange(int(np.floor(end*30/playback_speed))+1)*playback_speed/30
    np.column_stack([np.interp(frames,t,x[:,i]) for i in range(8)])
    np.testing.assert_array_equal(simulate(xr,zr,end,n)[2],x)
print('PASS: force construction, stability, static loads, flat road, equilibrium, independent ODE, contact detection, and rendering-independent solve')

# Parser checks actual MATLAB syntax, including tests; it does not execute MATLAB.
try:
    import tree_sitter_matlab
    from tree_sitter import Language, Parser
except ImportError:
    print('MATLAB syntax parser not installed; syntax parse skipped.')
else:
    parser=Parser(Language(tree_sitter_matlab.language()))
    for file in [ROOT/'half_car_model.m',ROOT/'simulate_half_car.m',ROOT/'tests/test_half_car_model.m']:
        tree=parser.parse(file.read_bytes())
        assert not tree.root_node.has_error, (file, tree.root_node)
        print('PASS: MATLAB syntax parse',file.name)

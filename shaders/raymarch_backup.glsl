#version 300 es
out vec4 out_FragColor;


//----------------------------------------------------------------------------------------------------------------------
// PARAMETERS
//----------------------------------------------------------------------------------------------------------------------

/*

Some parameters that can be changed to change the scence

*/

//determine what we draw: ball and lights,
const bool GLOBAL_SCENE=true;
const bool TILING_SCENE=false;
const bool EARTH=false;

//const bool TILING=false;
//const bool PLANES=false;

//bool DRAGON=!(TILING||PLANES);
//bool DRAGON_PLANE=not(TILING||PLANES);


const bool FAKE_LIGHT_FALLOFF=true;
const bool FAKE_LIGHT = true;
const bool FAKE_DIST_SPHERE = false;

//const float globalObjectRadius = 0.4;
const float centerSphereRadius =0.67;
const float vertexSphereSize = 0.23;//In this case its a horosphere
const float modelHalfCube = 0.5;

//----------------------------------------------------------------------------------------------------------------------
// "TRUE" CONSTANTS
//----------------------------------------------------------------------------------------------------------------------

const float PI = 3.1415926538;
const float sqrt3 = 1.7320508075688772;
const float sqrt2 = 1.4142135623730951;

vec3 debugColor = vec3(0.5, 0, 0.8);

//----------------------------------------------------------------------------------------------------------------------
// Global Constants
//----------------------------------------------------------------------------------------------------------------------
int MAX_MARCHING_STEPS =  60;
const float MIN_DIST = 0.0;
float MAX_DIST = 320.0;


void setResolution(int UIVar){
    if (UIVar==1){
        MAX_MARCHING_STEPS =  50;
        MAX_DIST = 100.0;
    }
    if (UIVar==2){
        MAX_MARCHING_STEPS =  200;
        MAX_DIST = 500.0;

    }
    if (UIVar==3){
        MAX_MARCHING_STEPS =  500;
        MAX_DIST = 1000.0;

    }
}

const float EPSILON = 0.0001;
//const float fov = 90.0;
const float fov = 120.0;

//----------------------------------------------------------------------------------------------------------------------
// Some global variables
//----------------------------------------------------------------------------------------------------------------------

int hitWhich = 0;


//----------------------------------------------------------------------------------------------------------------------
// Auxiliary methods: computations in SL(2,R) and X
//----------------------------------------------------------------------------------------------------------------------

/*

The elements of SL(2,R) seen as vectors in the basis E = (E0,E1,E2,E3)
See Jupyter Notebook
The elements satisfy the relation - x^2 - y^2 + z^2 + w^2 = -1

*/

// Correct the error to make sure that the point lies on the "hyperboloid"
vec4 SLreduceError(vec4 elt) {
    //float q = - elt.x * elt.x - elt.y * elt.y + elt.z * elt.z + elt.w * elt.w;
    mat4 J = mat4(
    -1, 0, 0, 0,
    0, -1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
    );
    float q = dot(elt, J * elt);
    return elt / sqrt(-q);
}

// change of model
// return the 2x2 matrix corresponding to elt
// Todo. Check if this is really needed
mat2 SLtoMatrix2(vec4 elt) {
    mat2 ex = mat2(
    1, 0,
    0, 1
    );
    mat2 ey = mat2(
    0, -1,
    1, 0
    );
    mat2 ez = mat2(
    0, 1,
    1, 0
    );
    mat2 ew = mat2(
    1, 0,
    0, -1
    );
    mat2 res = elt.x * ex + elt.y * ey + elt.z * ez + elt.w * ew;
    // reducing the eventual error
    res = res / sqrt(determinant(res));
    return res;
}
// change of model
// take a 2x2 matrix and return the corresponding element
vec4 SLfromMatrix2(mat2 m) {
    float a = m[0][0];
    float b = m[1][0];
    float c = m[0][1];
    float d = m[1][1];
    vec4 res = 0.5 * vec4(a + d, b - c, b + c, a - d);
    return SLreduceError(res);
}

// Projection from SL(2,R) to SO(2,1)
mat3 SLtoMatrix3(vec4 elt){
    mat4x3 aux1 = mat4x3(
    elt.x, elt.y, elt.z,
    -elt.y, elt.x, elt.w,
    elt.z, elt.w, elt.x,
    -elt.w, elt.z, elt.y
    );
    mat3x4 aux2 = mat3x4(
    elt.x, elt.y, elt.z, elt.w,
    -elt.y, elt.x, elt.w, -elt.z,
    elt.z, elt.w, elt.x, elt.y
    );
    mat3 res = aux1 * aux2;
    return res;
}

// Projection onto H^2
vec3 SLtoH2(vec4 elt) {
    mat3 m = SLtoMatrix3(elt);
    vec3 res = vec3(0., 0., 1.);
    res = m * res;
    // reduce the potential error
    // the point should be on a hyperboloid
    mat3 J = mat3(
    1, 0, 0,
    0, 1, 0,
    0, 0, -1
    );
    float q = dot(res, J * res);
    res = res / sqrt(-q);
    return res;
}

// Return the inverse of the given element
vec4 SLgetInverse(vec4 elt) {
    vec4 res = vec4(elt.x, -elt.y, -elt.z, -elt.w);
    return SLreduceError(res);
}

// Return the 4x4 Matrix, corresponding to the current element, seen as an isometry of SL(2,R)
mat4 SLtoMatrix4(vec4 elt) {
    mat4 res = mat4(
    elt.x, elt.y, elt.z, elt.w,
    -elt.y, elt.x, elt.w, -elt.z,
    elt.z, elt.w, elt.x, elt.y,
    elt.w, -elt.z, -elt.y, elt.x
    );
    return res;
}

// Multiply two elements of SL2 in the following order: elt1 * elt2
vec4 SLmultiply(vec4 elt1, vec4 elt2) {
    mat4 L1 = SLtoMatrix4(elt1);
    return SLreduceError(L1 * elt2);
}

// Translate the element by the given angle along the fiber
vec4 SLtranslateFiberBy(vec4 elt, float angle) {
    float aux = 0.5 * angle;
    mat4 T = mat4(
    cos(aux), sin(aux), 0., 0.,
    -sin(aux), cos(aux), 0., 0.,
    0., 0., cos(aux), -sin(aux),
    0., 0., sin(aux), cos(aux)
    );
    return SLreduceError(T * elt);
}

// Rotate the element by an angle alpha (see Jupyter Notebook)
vec4 SLrotateBy(vec4 elt, float angle) {
    mat4 R = mat4(
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, cos(angle), sin(angle),
    0, 0, -sin(angle), cos(angle)
    );
    return SLreduceError(R * elt);
}

// Flip the elemnt (see Jupyter Notebook)
vec4 SLflip(vec4 elt) {
    mat4 F = mat4(
    1, 0, 0, 0,
    0, -1, 0, 0,
    0, 0, 0, 1,
    0, 0, 1, 0
    );
    return SLreduceError(F * elt);
}


//----------------------------------------------------------------------------------------------------------------------
// STRUCT Point
//----------------------------------------------------------------------------------------------------------------------

/*

    Data type for points in the space X
    A point x in X is represented by a pair (proj,fiber) where
    - proj is the projection of x to SL(2,R) seen as a vec4 (in the basis E)
    - fiber is the fiber coordinates (!)

    The goal of this choice is to perform as many computations in SL(2,R) rather than in X.
    Hopefully this will reduce numerical erros related to the atan function

*/

struct Point {
    vec4 proj;// the projection of the point to SL(2,R)
    float fiber;// the fiber component
};

// origin of the space
// - the projection corresponds to the identity in SL(2,R)
// - the fiber component is zero
const Point ORIGIN = Point(vec4(1, 0, 0, 0), 0.);

// change of model
// the input is a vector (x,y,z,w) representing a point p where
// - (x,y,z) is the projection of p in H^2 (hyperboloid model)
// - w is the fiber coordinate
Point fromVec4(vec4 p) {
    vec4 proj = vec4(
    sqrt(0.5 * p.z + 0.5),
    0.,
    p.x / sqrt(2. * p.z + 2.),
    p.y / sqrt(2. * p.z + 2.)
    );
    // SLtranslateFiberBy already reduces the error, no need to do it again after
    proj = SLtranslateFiberBy(proj, p.w);
    return Point(proj, p.w);
}

// change of model
// the output is a vector (x,y,z,w) representing a point p where
// - (x,y,z) is the projection of p in H^2 in the **hyperboloid** model
// - w is the fiber coordinate
vec4 toVec4(Point p) {
    vec4 res;
    // SLtoH2 already reduces the error, no need to do it again after
    res.xyz = SLtoH2(p.proj);
    res.w = p.fiber;
    return res;
}

// change of model
// the output is a vector (x,y,1,w) representing a point p where
// - (x,y) is the projection of p in H^2 in the **Klein** model
// - w is the fiber coordinate
vec4 toKlein(Point p){
    // toVec4 already reduces the error, no need to do it again after
    vec4 res = toVec4(p);
    res.xyz = res.xyz / res.z;
    return res;
}

// unserialize the data received from the shader to create a point
Point unserializePoint(vec4 data) {
    return fromVec4(data);
}


//----------------------------------------------------------------------------------------------------------------------
// STRUCT Isometry
//----------------------------------------------------------------------------------------------------------------------

/*

  Data type for manipulating isometries of the space
  In this geometry we only consider as isometries the element of X acting on itself on the left.
  If x is a point of X, the isometry L_x sending the origin to x is represented by the point x

*/

struct Isometry {
    Point target;// the image of the origin by this isometry.
};

Isometry identity=Isometry(ORIGIN);

// Method to unserialized isometries passed to the shader
Isometry unserializeIsom(vec4 data) {
    Point p = fromVec4(data);
    return Isometry(p);
}

// Product of two isometries (more precisely isom1 * isom2)
Isometry composeIsometry(Isometry isom1, Isometry isom2) {
    Point target1 = isom1.target;
    Point target2 = isom2.target;
    float shift = target1.fiber + target2.fiber;
    // SLmultiply already reduces the error, no need to do it again after
    vec4 proj = SLmultiply(target1.proj, target2.proj);
    // SLtranslateFiberBy already reduces the error, no need to do it again after
    vec4 aux = SLtranslateFiberBy(proj, - shift);
    float fiber = shift + 2. * atan(aux.y, aux.x);
    Point target = Point(proj, fiber);
    return Isometry(target);
}

// Return the inverse of the given isometry
Isometry getInverse(Isometry isom) {
    // SLgetInverse already reduces the error, no need to do it again after
    vec4 proj = SLgetInverse(isom.target.proj);
    Point target = Point(proj, -isom.target.fiber);
    return Isometry(target);
}

// Return the isometry sending the origin to p
Isometry makeLeftTranslation(Point target) {
    return Isometry(target);
}

// Return the isometry sending p to the origin
Isometry makeInvLeftTranslation(Point p) {
    return getInverse(makeLeftTranslation(p));
}

// Translate a point by the given isometry
Point translate(Isometry isom, Point p) {
    Isometry aux = makeLeftTranslation(p);
    aux = composeIsometry(isom, aux);
    return aux.target;
}

// Perfom a rotation (meant in the H^2 component) by the given angle
// It does not affact the fiber component
Point rotateBy(Point p, float angle) {
    return Point(
    SLrotateBy(p.proj, angle),
    p.fiber
    );
}

// Flip the point (see Jupyter Notebook)
// It reverses the fiber
Point flip(Point p) {
    return Point(
    SLflip(p.proj),
    - p.fiber
    );
}


//----------------------------------------------------------------------------------------------------------------------
// STRUCT Vector
//----------------------------------------------------------------------------------------------------------------------


/*
  Data type for manipulating points in the tangent bundle
  A Vector is given by
  - pos : a point in the space
  - dir: a tangent vector at pos

  Local direction are vec3 written in the orthonormal basis (e_x, e_y, e_phi) where
  . e_x is the direction of the x coordinate of H^2
  . e_y is the direction of the y coordinate in H^2
  . e_phi is the direction of the fiber

  Implement various basic methods to manipulate them

*/


struct Vector {
    Point pos;// position on the manifold
    vec3 dir;// pull back of the tangent vector at the origin written in the appropriate basis
};

//----------------------------------------------------------------------------------------------------------------------
// Conversion between global and local representations of tangent vectors
//----------------------------------------------------------------------------------------------------------------------

/*

The methods below compute (if needed) the global/local direction of the given tangent vector
The tangent vector is passed as a reference, hence it is altered by the function

*/

// Return the differential of the isometry sending the origin to target
mat4 diffTranslation(Point target) {
    vec4 aux = toVec4(target);
    float x = aux.x;
    float y = aux.y;
    float z = aux.z;
    float w = aux.w;
    float aux1 = x * cos(w) + y * sin(w);
    float aux2 = y * cos(w) - x * sin(w);

    // differential map of the translation from the origin to pos
    mat4 m = mat4(
    x * aux1 / (z + 1.) + cos(w), y * aux1 / (z + 1.) + sin(w), aux1, aux2 / (z + 1.),
    x * aux2 / (z + 1.) - sin(w), y * aux2 / (z + 1.) + cos(w), aux2, -aux1 / (z + 1.),
    0.5 * x, 0.5 * y, 0.5 * z + 0.5, 0.,
    0., 0., 0., 1.
    );

    return m;
}

// Return the inverse of the differential of the isometry sending the origin to target
mat4 diffInvTranslation(Point target) {
    vec4 aux = toVec4(target);
    float x = aux.x;
    float y = aux.y;
    float z = aux.z;
    float w = aux.w;
    float aux1 = x * cos(w) + y * sin(w);
    float aux2 = y * cos(w) - x * sin(w);

    // inverse of the differential map of the translation from the origin to pos
    mat4 m = mat4(
    cos(w), -sin(w), -2. * x / (z + 1.), - y / (z + 1.),
    sin(w), cos(w), -2. * y / (z + 1.), x / (z + 1.),
    - aux1 / (z + 1.), -aux2 / (z + 1.), 2. * z / (z + 1.), 0.,
    0., 0., 0., 1.
    );

    return m;
}


//----------------------------------------------------------------------------------------------------------------------
// Applying Isometries, Facings
//----------------------------------------------------------------------------------------------------------------------


// overlaod using Vector
Isometry makeLeftTranslation(Vector v) {
    return makeLeftTranslation(v.pos);
}

// overlaod using Vector
Isometry makeInvLeftTranslation(Vector v) {
    return makeInvLeftTranslation(v.pos);
}

// overload to translate a direction
Vector translate(Isometry isom, Vector v) {
    return Vector(
    translate(isom, v.pos),
    v.dir
    );
}


// rotate the tangent vector (position and direction around the fiber by an angle alpha)
Vector rotateBy(Vector v, float angle) {
    mat3 rotD = mat3(
    cos(angle), sin(angle), 0,
    -sin(angle), cos(angle), 0,
    0, 0, 1
    );

    return Vector(rotateBy(v.pos, angle), rotD * v.dir);
}

// flip the tangent vector (see Jupyter Notebook)
Vector flip(Vector v) {
    mat3 flipD = mat3(
    0, 1, 0,
    1, 0, 0,
    0, 0, -1
    );

    return Vector(flip(v.pos), flipD * v.dir);
}

// apply a local rotation of the direction
Vector rotateByFacing(mat4 mat, Vector v){
    // notice that the facing is an element of SO(3) which refers to the basis (e_x, e_y, e_w).
    vec4 aux = vec4(v.dir, 0.);
    aux = mat * aux;

    return Vector(v.pos, aux.xyz);
}


//----------------------------------------------------------------------------------------------------------------------
// LOCAL GEOMETRY
//----------------------------------------------------------------------------------------------------------------------

/*
  Methods perfoming computations in the tangent space at a given point.
*/


// Add two tangent vector at the same point (return v1 + v2)
Vector add(Vector v1, Vector v2) {
    // return the added vectors
    return Vector(v1.pos, v1.dir + v2.dir);
}

// subtract two tangent vector at the same point (return v1 - v2)
Vector sub(Vector v1, Vector v2) {
    // return the added vectors
    return Vector(v1.pos, v1.dir - v2.dir);
}

// scalar multiplication of a tangent vector (return a * v)
Vector scalarMult(float a, Vector v) {
    return Vector(v.pos, a * v.dir);
}


// dot product of the two vectors
float tangDot(Vector v1, Vector v2){
    return dot(v1.dir, v2.dir);
}

// calculate the length of a tangent vector
float tangNorm(Vector v){
    return sqrt(tangDot(v, v));
}

// create a unit tangent vector (in the tangle bundle)
// when possible use the normalization method below
Vector tangNormalize(Vector v){
    // length of the vector
    float length = tangNorm(v);
    return Vector(v.pos, v.dir / length);
}


// cosAng between two vector in the tangent bundle
float cosAng(Vector v1, Vector v2){
    return tangDot(v1, v2);
}

Vector turnAround(Vector v){
    return Vector(v.pos, -v.dir);
}


//reflect the unit tangent vector u off the surface with unit normal n
Vector reflectOff(Vector v, Vector n){
    return sub(scalarMult(2.0 * tangDot(v, n), n), v);
}


/*

For the next four method,
we implictely assume that we have a prefered basis f = (f_x, f_y, f_z)
at of the tangent space at the point p

The first function compute (an approximation of) the point
obtained from p by following for a time eps the pass directed a vector given in the coordinates of f

The last method takes the coordinates of a tangent vector in this basis and return the corresponding tangent vector

Here the basis at p is the image by dL of the standard basis at the origin.

*/


Point smallShift(Point p, vec3 dp) {
    // direction dp pushed at the origin in SL(2,R)
    vec4 SLdirAtOrigin = 0.5 * vec4(0, dp.z, dp.x, dp.y);
    // direction dp pushed at p.proj in SL(2,R)
    vec4 SLdirAtP =  SLtoMatrix4(p.proj) * SLdirAtOrigin;

    // fiber component of the direction pushed at p
    float den = p.proj.x * p.proj.x + p.proj.y * p.proj.y;
    float coeffX = (p.proj.x * p.proj.w - p.proj.y * p.proj.z) / den;
    float coeffY = -(p.proj.x * p.proj.z + p.proj.y * p.proj.w) / den;
    float dfiberAtP = coeffX * dp.x + coeffY * dp.y + dp.z;


    vec4 newProj = SLreduceError(p.proj + SLdirAtP);
    float newFiber = p.fiber + dfiberAtP;

    return Point(newProj, newFiber);
}

Vector createVector(Point p, vec3 dp) {
    return Vector(p, dp);
}


//----------------------------------------------------------------------------------------------------------------------
// GLOBAL GEOMETRY
//----------------------------------------------------------------------------------------------------------------------

/*
  Methods computing ``global'' objects
*/


float _fakeDistToOrigin(Point p) {
    vec4 aux = toVec4(p);
    //debugColor = p.fiber * vec3(0, 0, 1);
    vec3 oh = vec3(0, 0, 1);
    mat3 J = mat3(
    1, 0, 0,
    0, 1, 0,
    0, 0, -1
    );
    float q = dot(aux.xyz, J * oh);
    return 0.5 * sqrt(pow(acosh(-q), 2.) + pow(aux.w, 2.));
}

// fake distance between two points
float fakeDistance(Point p1, Point p2){
    Isometry shift = makeInvLeftTranslation(p1);
    //Isometry shift = identity;
    //debugColor = length(shift.target.proj - identity.target.proj) * vec3(1, 1, 1);
    //debugColor = abs(shift.target.fiber - identity.target.fiber) * vec3(1, 1, 1);

    Point aux = translate(shift, p2);
    //debugColor = length(p2.proj - aux.proj) * vec3(1, 1, 1);
    //debugColor = abs(p2.fiber - aux.fiber) * vec3(1, 1, 1);
    return _fakeDistToOrigin(aux);

    /*
    Isometry isom = makeInvLeftTranslation(p1);
    vec4 aux = toVec4(translate(isom, p2));
    vec3 oh = vec3(0, 0, 1);
    mat3 J = mat3(
    1, 0, 0,
    0, 1, 0,
    0, 0, -1
    );
    float q = dot(aux.xyz, J * oh);
    return sqrt(pow(acosh(-q), 2.) + pow(aux.w, 2.));
    */

    /*
    vec4 aux1 = toVec4(p1);
    vec4 aux2 = toVec4(p2);
    return length(aux2 - aux1);
    */

    /*
    Isometry shift = makeInvLeftTranslation(p1);
    return length(toVec4(translate(shift, p2)));
    */
}

// overload of the previous function in case we work with tangent vectors
float fakeDistance(Vector v1, Vector v2){
    return fakeDistance(v1.pos, v2.pos);
}


//-----------------------------------------------------------------------
// Binary search / Newton method for computing the exact distance
//-----------------------------------------------------------------------


// TODO. Use asymptotic expansion around the parabolic type geodesics?


// consider a geodesic gamma from the origin describing an angle phi
// when reaching the point at distance rho of the axis (O,w)
// return the value of 0.5(w - w0), where w is the height of gamma at that point
// the distance rho is pased as rho^2
float fiberHeight(float shRhoOver2SQ, float w0, float phi) {
    float shRhoOver2 = sqrt(shRhoOver2SQ);
    float chRhoOver2 = sqrt(1. + shRhoOver2SQ);
    float tanPhi = tan(phi);
    float tanPhiSQ = pow(tanPhi, 2.);
    float aux;
    float res;
    if (abs(phi) < 0.5 * PI) {
        if (abs(tanPhi) < shRhoOver2){
            aux = sqrt(shRhoOver2SQ - tanPhiSQ) / chRhoOver2;
            res = (phi - 0.5 * w0)  - 2. *  tanPhi * atanh(aux) / aux;
        }
        else if (abs(tanPhi) == shRhoOver2) {
            res = (phi - 0.5 * w0) - 2. * tanPhi;
        }
        else if (abs(tanPhi) > shRhoOver2){
            aux = sqrt(tanPhiSQ - shRhoOver2SQ) / chRhoOver2;
            res = (phi - 0.5 * w0) - 2. * tanPhi * atan(aux) / aux;
        }
    }
    else if (abs(phi) == 0.5 * PI) {
        res = - 0.5 * w0 - sign(phi) * PI * (chRhoOver2 - 0.5);
    }
    else {
        aux = sqrt(tanPhiSQ - shRhoOver2SQ) / chRhoOver2;
        res = (phi - 0.5 * w0) - 2. * tanPhi * (atan(aux)-PI) / aux;
    }
    return res;
}

// IN PROGRESS BEGIN !!

// assume that a geodesic starting from the origin reach the point q
// after describing an angle theta (in the hyperbolic plane)
// return the length of this geodesic
// we assume that rho > 0 and z > 0
void _lengthFromPhi(float shRhoOver2SQ, float w, float phi, out float len) {

    float shRhoOver2 = sqrt(shRhoOver2SQ);
    float chRhoOver2 = sqrt(1. + shRhoOver2SQ);

    float tanPhi = tan(phi);
    float tanPhiSQ = pow(tanPhi, 2.);

    float omega;
    float omega2;

    if (abs(tanPhi) < shRhoOver2) {
        // hyperbolic type geodesic
        // omega = sqrt(a^2 - c^2)
        omega2 = (shRhoOver2SQ - tanPhiSQ) / ((2.* shRhoOver2SQ +1.) * tanPhiSQ + shRhoOver2SQ);
        omega = sqrt(omega2);
        len = 2. * atanh(sqrt(shRhoOver2SQ - tanPhiSQ) / chRhoOver2) / omega;

    }
    else if (abs(tanPhi) == shRhoOver2) {
        // parabolic type geodesic
        len = 2. * sqrt2 * shRhoOver2;
    }
    else {
        // elliptic type geodesic
        // omega = sqrt(c^2 - a^2)
        omega2 = (tanPhiSQ - shRhoOver2SQ) / ((2.* shRhoOver2SQ +1.) * tanPhiSQ + shRhoOver2SQ);
        omega = sqrt(omega2);
        len = 2. * atan(sqrt(tanPhiSQ - shRhoOver2SQ) / chRhoOver2) / omega;
        // geodesic that made more than a half turn
        if (abs(w) > PI * (chRhoOver2 - 0.5)) {
            len = len + sign(w) * 2. * PI / omega;
        }
    }
}

// assume that a geodesic starting from the origin reach the point q
// after describing an angle phi (in the hyperbolic plane)
// return the unit tangent vector of this geodesic and its length
// we assume that rho > 0
void _dirLengthFromPhi(float shRhoOver2SQ, float theta, float w, float phi, out Vector tv, out float len) {

    float shRhoOver2 = sqrt(shRhoOver2SQ);
    float chRhoOver2 = sqrt(1. + shRhoOver2SQ);

    float tanPhi = tan(phi);
    float tanPhiSQ = pow(tanPhi, 2.);

    float omega;
    float omega2;
    float a;
    float c;

    if (abs(tanPhi) < shRhoOver2) {
        // hyperbolic type geodesic
        // omega = sqrt(a^2 - c^2)
        omega2 = (shRhoOver2SQ - tanPhiSQ) / ((2.* shRhoOver2SQ +1.) * tanPhiSQ + shRhoOver2SQ);
        omega = sqrt(omega2);
        a = sqrt(0.5 * (1. + omega2));
        c = sign(w) * sqrt(0.5 * (1. - omega2));
        len = 2. * atanh(sqrt(shRhoOver2SQ - tanPhiSQ) / chRhoOver2) / omega;

    }
    else if (abs(tanPhi) == shRhoOver2) {
        // parabolic type geodesic
        a = 1. / sqrt2;
        c = sign(w) * 1. / sqrt2;
        len = 2. * sqrt2 * shRhoOver2;
    }
    else {
        // elliptic type geodesic
        // omega = sqrt(c^2 - a^2)
        omega2 = (tanPhiSQ - shRhoOver2SQ) / ((2.* shRhoOver2SQ +1.) * tanPhiSQ + shRhoOver2SQ);
        omega = sqrt(omega2);
        a = sqrt(0.5 * (1. - omega2));
        c = sign(w) * sqrt(0.5 * (1. + omega2));
        len = 2. * atan(sqrt(tanPhiSQ - shRhoOver2SQ) / chRhoOver2) / omega;
        // geodesic that made more than a half turn
        if (abs(w) > PI * (chRhoOver2 - 0.5)) {
            len = len + sign(w) * 2. * PI / omega;
        }
    }
    float alpha = theta + c * len - 0.5 * w;
    tv = Vector(ORIGIN, vec3(a * cos(alpha), a * sin(alpha), c));
}


// IN PROGRESS STOP !!

// Consider a minimizing geodesic gamma starting at the origin with tangent vector of the form (a,0,c)
// Assume that after time t its polar coordinates are (rho, theta, phi).
// The function takes as an input rho -- given as sinh(rho/2)^2 -- phi and w
// and returns (a,c,t) in a vec3
vec3 computeParams(float shRhoOver2SQ, float phi, float w){

    float shRhoOver2 = sqrt(shRhoOver2SQ);
    float chRhoOver2 = sqrt(1. + shRhoOver2SQ);

    float tanTheta = tan(phi);
    float tanThetaSQ = pow(tanTheta, 2.);

    float omega;
    float omega2;
    float a;
    float c;
    float t;

    if (abs(tanTheta) < shRhoOver2) {
        // hyperbolic type geodesic
        // omega = sqrt(a^2 - c^2)
        omega2 = (shRhoOver2SQ - tanThetaSQ) / ((2.* shRhoOver2SQ +1.) * tanThetaSQ + shRhoOver2SQ);
        omega = sqrt(omega2);
        a = sqrt(0.5 * (1. + omega2));
        c = sign(w) * sqrt(0.5 * (1. - omega2));
        t = 2. * atanh(sqrt(shRhoOver2SQ - tanThetaSQ) / chRhoOver2) / omega;

    }
    else if (abs(tanTheta) == shRhoOver2) {
        // parabolic type geodesic
        a = 1. / sqrt2;
        c = sign(w) * 1. / sqrt2;
        t = 2. * sqrt2 * shRhoOver2;
    }
    else {
        // elliptic type geodesic
        // omega = sqrt(c^2 - a^2)
        omega2 = (tanThetaSQ - shRhoOver2SQ) / ((2.* shRhoOver2SQ +1.) * tanThetaSQ + shRhoOver2SQ);
        omega = sqrt(omega2);
        a = sqrt(0.5 * (1. - omega2));
        c = sign(w) * sqrt(0.5 * (1. + omega2));
        t = 2. * atan(sqrt(tanThetaSQ - shRhoOver2SQ) / chRhoOver2) / omega;
        // geodesic that made more than a half turn
        if (abs(w) > PI * (chRhoOver2 - 0.5)) {
            t = t + sign(w) * 2. * PI / omega;
        }
    }
    return vec3(a, c, t);
}

int DICHOTOMY_MAX_STEPS = 10;
float DICHOTOMY_THRESHOLD = 0.01;

// given rho and w, find the parameter phi between phiMin and phiMax
// which (almos) vanishes the function fiberHeight.
// (One assumes that the problem has a solution on this interval)
float _dichoSearch(float shRhoOver2SQ, float w, float phiMin, float phiMax){
    float auxM = phiMin;
    float auxP = phiMax;
    float phi;
    float height;
    for (int i=0; i < DICHOTOMY_MAX_STEPS; i++) {
        if (abs(auxM - auxP) < DICHOTOMY_THRESHOLD) {
            break;
        }
        phi = 0.5 * auxM + 0.5 * auxP;
        height = fiberHeight(shRhoOver2SQ, w, phi);
        if (height > 0.) {
            auxM = phi;
        }
        else {
            auxP = phi;
        }
    }
    return phi;
}

// Take a point p and return the data (a,c,t) as a vec3
// such that the geodesic starting at the origin directed by (a,0,c)
// reach the point p after time t.
// The algorithm is a dichotomy.
// This part is mean as as a preliminary step for a Newtown algorithm.

vec3 _dichoDist(Point p) {
    // we assume that phi is positive (always possible up to flipping)
    // note that the flip does not change rho
    float phi = abs(p.fiber);
    float shRhoOver2SQ = pow(p.proj.z, 2.) + pow(p.proj.w, 2.);
    float shRhoOver2 = sqrt(shRhoOver2SQ);
    float chRhoOver2 = sqrt(1. + shRhoOver2SQ);


    /*
    float thetaMin;
    float thetaMax;
    float thetaDicho;
    // we can detect in advance what kind of geodesic we are following
    // this allow to narrow a little the initial domain.
    // Note sure this is totally relevant, as it involved a lot of computation,
    // while one or two dichotomy step would bring us back to this level.
    if (0.5 * abs(phi) < 2. * shRhoOver2 - atan(shRhoOver2)){
        // hyperbolic type geodesic
        thetaMin = -atan(shRhoOver2);
        thetaMax = 0.;
        thetaDicho = _dichoSearch(shRhoOver2SQ, phi, thetaMin, thetaMax);
    }
    else if (0.5 * abs(phi) == abs(2. * shRhoOver2 - atan(shRhoOver2))) {
        // parabolic type geodesic
        thetaDicho = - atan(shRhoOver2);
    }
    else {
        if (0.5 * abs(phi) < PI * (chRhoOver2 - 0.5)){
            // geodesic with less than half a turn
            thetaMin = -0.5 * PI;
            thetaMax = -atan(shRhoOver2);
            thetaDicho = _dichoSearch(shRhoOver2SQ, phi, thetaMin, thetaMax);
        }
        else {
            // geodesic with at least half a turn
            thetaMin = atan(shRhoOver2) - PI;
            thetaMax = -0.5 * PI;
            thetaDicho = _dichoSearch(shRhoOver2SQ, phi, thetaMin, thetaMax);
        }
    }*/


    float thetaMin = atan(shRhoOver2) - PI;
    float thetaMax = 0.;
    float thetaDicho = _dichoSearch(shRhoOver2SQ, phi, thetaMin, thetaMax);


    //return vec3(thetaDicho);

    vec3 res = computeParams(shRhoOver2SQ, thetaDicho, phi);
    // if needed we flip back the result
    if (p.fiber < 0.) {
        res.y = -res.y;
    }
    return res;

}


float _exactDistToOrign(Point p) {
    vec3 params = _dichoDist(p);
    return params.z;

    //float res = _fakeDistToOrigin(p);
    //return res;

}


// distance between two points
float exactDist(Point p1, Point p2){
    Isometry isom = makeInvLeftTranslation(p1);
    return _exactDistToOrign(translate(isom, p2));
}

// overload of the previous function in case we work with tangent vectors
float exactDist(Vector v1, Vector v2){
    return exactDist(v1.pos, v2.pos);
}


// return the tangent vector at p point to q
Vector tangDirection(Point p, Point q){
    // isometry moving back p to the origin
    Isometry shift = makeInvLeftTranslation(p);
    // translation of q at the origin
    Point qAtOrigin = translate(shift, q);
    vec4 aux = toVec4(qAtOrigin);
    Vector res = Vector(p, aux.xyw);
    res = tangNormalize(res);
    return res;


    /*
    vec4 auxp = toVec4(p);
    vec4 auxq = toVec4(q);
    mat4 dLinv = diffInvTranslation(p);
    vec4 global_dir = auxq - auxp;
    global_dir = global_dir / length(global_dir);
    Vector res = Vector(p, (dLinv * global_dir).xyw);
    res = tangNormalize(res);
    return res;
    */
}

// overload of the previous function in case we work with tangent vectors
Vector tangDirection(Vector u, Vector v){
    return tangDirection(u.pos, v.pos);
}


// flow the given vector during time t using exact formulas
// this method is to be called  by `flow`
// we make the following assumtions
// - the initial position of v is the origin
// - the local direction of v is set up
// - the initial direction has the local form (a, 0, c), with a,c > 0
Vector _exactFlow(Vector v, float t) {
    Vector res;

    float a = v.dir.x;
    float c = v.dir.z;

    float w = 2. * c * t;// the angle in the fiber achieved by the geodesic (before final adjustment)
    float kappaSq = 0.;
    float kappa = 0.;// the "pulsatance" involved in the geodesic flow.
    float phi = 0.;// the rotation angle in H^2.


    // the solution has an easy description as a product of 2 x 2 matrices.
    // it is a product of isom * spin where
    // - isom is a one-parameter subgroup of SL(2,R) (elliptic, parabolic, or hyperbolic)
    // - spin is a one-parameter subgroup of SL(2,R) fixing the origin of H^2.
    // we use this form, and then convert it into a vec4

    // the spin part is always the same.
    mat2 spin = mat2(
    cos(c * t), -sin(c * t),
    sin(c * t), cos(c * t)
    );
    // to get the fiber angle we will go through the projection of the point in H^2
    // (see Jupyter Notebook)

    // we distinguish three cases, depending whether c is smaller, equal or greater than a.
    // it corresponds to the three cases for isom (elliptic, parabolic, or hyperbolic).


    // little hack to see the junction between elliptic/hyperbolic behavior
    /*
    if (abs(c-a) < 0.002) {
        hitWhich = 5;
        debugColor = vec3(1,1,0);
    }
    */

    /*
    if (abs(c-a)*t < 0.05) {
        // "parabolic" trajectory
        // we use an asymptotic expansion of the solution around the critical case (c = a) to reduce the noise.
        float a2 = a * a;
        float kappa2 = a * a - c * c;
        float kappa4 = kappa2 * kappa2;
        float kappa6 = kappa4 * kappa2;
        float kappa8 = kappa6 * kappa2;
        float t2 = t * t;
        float t3 = t2 * t;
        float t4 = t3 * t;
        float t5 = t4 * t;
        float t6 = t5 * t;
        float t7 = t6 * t;
        float t8 = t7 * t;

        mat2 even = mat2(1);
        mat2 odd = mat2(0, a + c, a - c, 0);
        mat2 isom = even;
        isom = isom + t * (1. / 2.) * odd;
        isom = isom + (1./2.) * t2 * (1. / 4.) * kappa2 * even;
        isom = isom + (1./6.) * t3 * (1. / 8.) * kappa2 * odd;
        isom = isom + (1./24.) * t4 * (1. / 16.) * kappa4 * even;
        isom = isom + (1./120.) * t5 * (1. / 32.) * kappa4 * odd;
        isom = isom + (1./720.) * t6 * (1. / 64.) * kappa6 * even;
        isom = isom + (1./5040.) * t7 * (1. / 128.) * kappa6 * odd;
        isom = isom + (1./40320.) * t8 * (1. / 256.) * kappa8 * even;

        res.pos.proj = SLfromMatrix2(isom * spin);

        float tanPhi = - a * c * t / 2. - a * c * kappa2 * t3 / 24. - a * c * kappa4 * t5 / 720. - a * c * kappa6 * t7 / 40320.;
        tanPhi = tanPhi /(a + a * t2 * kappa2 / 6. + a * t4 * kappa4 / 120. + a * t6 * kappa6 /5040.);
        res.pos.fiber = w + atan(tanPhi);
     }
     */
    if (abs(c-a) == 0.) {
        // parabolic trajectory
        mat2 isom = mat2(
        1, t/sqrt2,
        0, 1
        );
        res.pos.proj = SLfromMatrix2(isom * spin);

        float tanPhi = - t / (2. * sqrt2);
        res.pos.fiber = w + 2. * atan(tanPhi);

    }
    else if (c < a){
        // hyperbolic trajectory
        kappaSq = a * a - c * c;
        kappa = sqrt(kappaSq);

        mat2 isom = mat2(
        cosh(0.5 * kappa * t), kappa * sinh(0.5 * kappa * t) / (a-c),
        kappa * sinh(0.5 * kappa * t) / (a+c), cosh(0.5 * kappa * t)
        );
        res.pos.proj = SLfromMatrix2(isom * spin);

        float tanPhi = - c / kappa * tanh(0.5 * kappa * t);
        res.pos.fiber = w + 2. * atan(tanPhi);

    }
    else {
        // remaining case c > a
        // elliptic trajectory

        kappaSq = c * c - a * a;
        kappa = sqrt(kappaSq);

        mat2 isom = mat2(
        cos(0.5 * kappa * t), -kappa * sin(0.5 * kappa * t) / (a-c),
        -kappa * sin(0.5 * kappa * t) / (a+c), cos(0.5 * kappa * t)
        );
        res.pos.proj = SLfromMatrix2(isom * spin);

        float aux = floor(0.5 * kappa * t / PI + 0.5);
        float tanPhi = - c / kappa * tan(0.5 * kappa * t);
        res.pos.fiber = w + 2. * atan(tanPhi) - 2. * aux * PI;

    }

    // update the direction of the tangent vector
    // recall that tangent vectors at the origin have the form (ux,uy,uw)
    // so we work with 3x3 matrics applied to local_dir
    mat3 S = mat3(
    cos(2. * c * t), -sin(2. * c * t), 0.,
    sin(2. * c * t), cos(2. * c * t), 0.,
    0., 0., 1.
    );
    res.dir = S * v.dir;
    return res;
}


// flow the given vector during time t
Vector flow(Vector v, float t) {
    // -------------------------------------------------------
    // prepation : set the vector into an easier form to flow
    // -------------------------------------------------------

    // isometry sending the origin the the position of v
    Isometry isom = makeLeftTranslation(v);
    // pull back the tangent vector a the origin (very easy in the local representation)
    Vector vAtOrigin = Vector(ORIGIN, v.dir);
    // flip if needed to get a positive fiber direction
    bool flipped = false;
    if (vAtOrigin.dir.z < 0.) {
        flipped = true;
        vAtOrigin = flip(vAtOrigin);
    }
    // rotation
    // the angle alpha is characterized as follows
    // if u is a tangent vector with the local form (a, 0, c) with a, c >= 0
    // then v is obtained from u by a rotation of angle alpha
    float alpha = atan(vAtOrigin.dir.y, vAtOrigin.dir.x);
    float c = vAtOrigin.dir.z;
    float a = sqrt(1. - c * c);
    vAtOrigin.dir = vec3(a, 0., c);

    // -------------------------------------------------------
    // flow the vector
    // -------------------------------------------------------
    Vector resAtOrigin = _exactFlow(vAtOrigin, t);

    // -------------------------------------------------------
    // reverse the preparation done at the beginning
    // -------------------------------------------------------
    resAtOrigin = rotateBy(resAtOrigin, alpha);
    if (flipped) {
        resAtOrigin = flip(resAtOrigin);
    }

    Vector res = translate(isom, resAtOrigin);
    res = tangNormalize(res);
    return res;
}


//----------------------------------------------------------------------------------------------------------------------
// LIGHT
//----------------------------------------------------------------------------------------------------------------------
//light intensity as a fn of distance
float lightAtt(float dist){
    if (FAKE_LIGHT_FALLOFF){
        //fake linear falloff
        return dist;
    }
    return dist*dist;
}


//----------------------------------------------------------------------------------------------------------------------
// Raymarch Primitives
//----------------------------------------------------------------------------------------------------------------------


float sphereSDF(Point p, Point center, float radius){
    return fakeDistance(p, center) - radius;
    //return exactDist(p, center) - radius;
}

float cylSDF(Point p, float r){
    vec4 aux = toVec4(p);
    mat3 J = mat3(
    1, 0, 0,
    0, 1, 0,
    0, 0, -1
    );
    float s = 0.;
    vec3 center = vec3(0., s, sqrt(1. + s * s));
    float q = dot(aux.xyz, J * center);
    return acosh(-q) - r;
}


// fake ellipsoid centered at the origin
float ellipsoidSDF(Point p, float radius, float wRescale){
    vec4 aux = toVec4(p);
    vec3 oh = vec3(0, 0, 1);
    mat3 J = mat3(
    1, 0, 0,
    0, 1, 0,
    0, 0, -1
    );
    float q = dot(aux.xyz, J * oh);
    float dist = 0.5 * sqrt(pow(acosh(-q), 2.) + pow(aux.w / wRescale, 2.));
    return dist - radius;
}

/*
float centerSDF(vec4 p, vec4 center, float radius){
    return sphereSDF(p, center, radius);
}


float vertexSDF(vec4 p, vec4 cornerPoint, float size){
    return sphereSDF(abs(p), cornerPoint, size);
}

float horizontalHalfSpaceSDF(vec4 p, float h) {
    //signed distance function to the half space z < h
    return p.z - h;
}


float sliceSDF(vec4 p) {
    float HS1= 0.;
    HS1=horizontalHalfSpaceSDF(p, -0.1);
    float HS2=0.;
    HS2=-horizontalHalfSpaceSDF(p, -1.);
    return max(HS1, HS2);
}


*/


//----------------------------------------------------------------------------------------------------------------------
// Global Variables
//----------------------------------------------------------------------------------------------------------------------
Vector N;//normal vector
Vector sampletv;
vec4 globalLightColor;
Isometry currentBoost;
Isometry leftBoost;
Isometry rightBoost;
Isometry cellBoost;
Isometry invCellBoost;
Isometry globalObjectBoost;

//----------------------------------------------------------------------------------------------------------------------
// Translation & Utility Variables
//----------------------------------------------------------------------------------------------------------------------
uniform int isStereo;
uniform vec2 screenResolution;
uniform vec4 invGenerators[10];//
uniform vec4 currentBoostMat;
uniform vec4 leftBoostMat;
uniform vec4 rightBoostMat;
uniform mat4 facing;
uniform mat4 leftFacing;
uniform mat4 rightFacing;
uniform vec4 cellBoostMat;
uniform vec4 invCellBoostMat;

//----------------------------------------------------------------------------------------------------------------------
// Lighting Variables & Global Object Variables
//----------------------------------------------------------------------------------------------------------------------
uniform vec4 lightPositions[4];
uniform vec4 lightIntensities[4];
uniform vec4 globalObjectBoostMat;
uniform float globalSphereRad;
uniform samplerCube earthCubeTex;
uniform float time;
uniform float lightRad;

uniform int display;
// 1=tiling
// 2= planes
// 3= dragon skin

uniform int resol;

//adding one local light (more to follow)
Point localLightPos;
vec4 localLightColor=vec4(1., 1., 1., 0.2);

//variable which sets the light colors for drawing in hitWhich 1
vec3 colorOfLight=vec3(1., 1., 1.);


//----------------------------------------------------------------------------------------------------------------------
// Re-packaging isometries, facings in the shader
//----------------------------------------------------------------------------------------------------------------------

//This actually occurs at the beginning of main() as it needs to be inside of a function


//----------------------------------------------------------------------------------------------------------------------
// Scene Definitions
//----------------------------------------------------------------------------------------------------------------------
// Turn off the local scene
// Local signed distance function : distance from p to an object in the local scene

float localSceneSDF(Point p){
    float sphDist;
    float tilingDist;
    float cylDist;
    float lightDist;
    float distance = MAX_DIST;

    lightDist=sphereSDF(p, localLightPos, lightRad);
    distance=min(distance, lightDist);
    if (lightDist < EPSILON){
        //LIGHT=true;
        hitWhich = 1;
        colorOfLight=vec3(1., 1., 1.);
        return lightDist;
    }

    // Sphere
    /*
    float aux = 0.;
    Point center = fromVec4(vec4(0., aux, sqrt(1. + aux * aux), 0));
    sphDist = sphereSDF(p, center, 0.1);
    distance = min(distance, sphDist);
    if (sphDist < EPSILON){
        hitWhich = 3;
        return sphDist;
    }
    */


    // Tiling

    tilingDist = -ellipsoidSDF(p, 0.9, 2.5);
    //tilingDist = -sphereSDF(p, ORIGIN, 3.);
    distance = min(distance, tilingDist);
    if (tilingDist < EPSILON){
        hitWhich=3;
        return tilingDist;
    }


    // Cylinders
    /*
    cylDist = cylSDF(p, 0.4);
    distance = min(distance, cylDist);
    if (cylDist < EPSILON){
        hitWhich=3;
        return cylDist;
    }
    */


    return distance;
}

//GLOBAL OBJECTS SCENE ++++++++++++++++++++++++++++++++++++++++++++++++
// Global signed distance function : distance from cellBoost * p to an object in the global scene
float globalSceneSDF(Point p){
    // correct for the fact that we have been moving
    Point absolutep = translate(cellBoost, p);
    float distance = MAX_DIST;
    float objDist;
    //Light Objects

    /*
    for (int i=0; i<4; i++){
        objDist = sphereSDF(absolutep, unserializePoint(lightPositions[i]), 0.1);
        distance = min(distance, objDist);
        if (distance < EPSILON){
            hitWhich = 1;
            colorOfLight = lightIntensities[i].xyz;
            globalLightColor = lightIntensities[i];
            return distance;
        }
    }*/


    //Global Sphere Object
    //Point globalObjPos1 = translate(globalObjectBoost, ORIGIN);
    Point globalObjPos1 = fromVec4(vec4(0, 0, 1, 1));
    objDist = sphereSDF(absolutep, globalObjPos1, 0.3);

    distance = min(distance, objDist);
    if (distance < EPSILON){
        hitWhich = 2;
        return distance;
    }


    return distance;
}


// Check if the given point p is in the fundamental domain of the lattice.
// Lattice = SL(2,Z)
bool isOutsideCellModular(Point p, out Isometry fixIsom){
    // point in the Klein model
    // (where the fundamental domain is convex polyhedron).
    vec4 klein = toKlein(p);

    // Normal defining the fundamental domain of SL(2,Z)
    vec4 n0 = vec4(0, -1, 0, 0);
    vec4 n2 = vec4(2, 1, 0, 0);
    vec4 n3 = vec4(-2, 1, 0, 0);
    vec4 n4 = vec4(0, 0, 0, 1);


    // lift of the rotation of angle pi around the origin
    Isometry gen0 = Isometry(Point(
    vec4(0, -1, 0, 0),
    - PI
    ));
    // lift the the parabolic z -> z - 1 (in the upper half plane model)
    Isometry gen2 = Isometry(Point(
    vec4(1, -0.5, -0.5, 0),
    -2. * atan(0.5)
    ));
    // lift the the parabolic z -> z + 1 (in the upper half plane model)
    // inverse of the previous one
    Isometry gen3 = Isometry(Point(
    vec4(1, 0.5, 0.5, 0),
    2. * atan(0.5)
    ));
    // translation by -4pi along the fiber
    Isometry gen4 = Isometry(Point(
    vec4(1, 0, 0, 0),
    -4. * PI
    ));
    // translation by 4pi along the fiber
    Isometry gen5 = Isometry(Point(
    vec4(1, 0, 0, 0),
    4. * PI
    ));

    // testing if the point is in the fundamental domain, and the matrix to fix it

    if (dot(klein, n0) > 0.) {
        fixIsom = gen0;
        return true;
    }
    if (dot(klein, n2) > 1.) {
        fixIsom = gen2;
        return true;
    }
    if (dot(klein, n3) > 1.) {
        fixIsom = gen3;
        return true;
    }
    if (dot(klein, n4) > 2. * PI) {
        fixIsom = gen4;
        //debugColor = vec3(1,0,0);
        return true;
    }
    if (dot(klein, n4) < -2. * PI) {
        fixIsom = gen5;
        //debugColor = vec3(0,1,0);
        return true;
    }
    return false;
}


// Check if the given point p is in the fundamental domain of the lattice.
// Lattice : quadrangle
bool isOutsideCellSquare(Point p, out Isometry fixIsom){
    // point in the Klein model
    // (where the fundamental domain is convex polyhedron).
    vec4 klein = toKlein(p);

    // Normal defining the fundamental domain of the lattice
    vec4 np = vec4(1, 1, 0, 0);
    vec4 nm = vec4(-1, 1, 0, 0);
    vec4 nfiber = vec4(0, 0, 0, 1);

    // lift of the first rotation
    Isometry gen1 = Isometry(Point(
    vec4(sqrt3 / 2., sqrt3 / 2., sqrt2 / 2., 0),
    PI / 2.
    ));

    Isometry gen1inv = Isometry(Point(
    vec4(sqrt3 / 2., -sqrt3 / 2., -sqrt2 / 2., 0),
    -PI / 2.
    ));

    // lift of the second rotation
    Isometry gen2 = Isometry(Point(
    vec4(sqrt3 / 2., sqrt3 / 2., - sqrt2 / 2., 0),
    PI / 2.
    ));

    Isometry gen2inv = Isometry(Point(
    vec4(sqrt3 / 2., -sqrt3 / 2., sqrt2 / 2., 0),
    -PI / 2.
    ));

    // translation by 2pi along the fiber
    Isometry gen3 = Isometry(Point(
    vec4(-1, 0, 0, 0),
    2. * PI
    ));

    // translation by -2pi along the fiber
    Isometry gen3inv = Isometry(Point(
    vec4(-1, 0, 0, 0),
    - 2. * PI
    ));


    // testing if the point is in the fundamental domain, and the matrix to fix it

    float threshold = sqrt2 / sqrt3;

    if (dot(klein, nm) > threshold) {
        fixIsom = gen1;
        return true;
    }
    if (dot(klein, np) > threshold) {
        fixIsom = gen1inv;
        return true;
    }
    if (dot(klein, nm) < -threshold) {
        fixIsom = gen2;
        return true;
    }
    if (dot(klein, np) < -threshold) {
        fixIsom = gen2inv;
        return true;
    }
    if (dot(klein, nfiber) > PI) {
        fixIsom = gen3inv;
        return true;
    }
    if (dot(klein, nfiber) < -PI) {
        fixIsom = gen3;
        return true;
    }

    return false;
}

// Check if the given point p is in the fundamental domain of the discrete subgroup.
// Subgroup: translation along the fiber by a fixed angle
bool isOutsideCellFiber(Point p, out Isometry fixIsom){
    // no need here to consider the Klein model
    // everything takes place in the fiber coordinate

    // translation by pi/2 along the fiber
    Isometry gen = Isometry(Point(
    vec4(0.5 * sqrt3, 0.5, 0, 0),
    PI / 3.
    ));

    // translation by pi/2 along the fiber
    Isometry genInv = Isometry(Point(
    vec4(0.5 * sqrt3, -0.5, 0, 0),
    - PI / 3.
    ));

    if (p.fiber > PI / 6.) {
        fixIsom = genInv;
        return true;
    }
    if (p.fiber < - PI / 6.) {
        fixIsom = gen;
        return true;
    }
    return false;
}


/****************************************************

LATTICE CORRESPONDING TO A GENUS 2 SURFACE

*****************************************************/


// Check if the given point p is in the fundamental domain of the lattice.
// Lattice : surface of genus 2
bool isOutsideCellSurface(Point p, out Isometry fixIsom){
    // point in the Klein model
    // (where the fundamental domain is convex polyhedron).
    vec4 klein = toKlein(p);

    // Normal defining the fundamental domain of the lattice
    vec4 nh = vec4(1, 0, 0, 0);
    vec4 nv = vec4(0, 1, 0, 0);
    vec4 nd1 = vec4(0.5 * sqrt2, 0.5 * sqrt2, 0, 0);
    vec4 nd2 = vec4(-0.5 * sqrt2, 0.5 * sqrt2, 0, 0);
    vec4 nfiber = vec4(0, 0, 0, 1);


    float auxSurfaceP = sqrt(sqrt2 + 1.);
    float auxSurfaceM = sqrt(sqrt2 - 1.);

    // lifts of the 4 translations (and their inverses)
    Isometry genA1 = Isometry(Point(
    vec4(0.5 * sqrt2 + 1., 0.5 * sqrt2 + 1., auxSurfaceP, -auxSurfaceP),
    PI / 2.
    ));

    Isometry genA1inv = Isometry(Point(
    vec4(0.5 * sqrt2 + 1., -0.5 * sqrt2 - 1., -auxSurfaceP, auxSurfaceP),
    -PI / 2.
    ));

    Isometry genA2 = Isometry(Point(
    vec4(0.5 * sqrt2 + 1., 0.5 * sqrt2 + 1., -auxSurfaceP, auxSurfaceP),
    PI / 2.
    ));

    Isometry genA2inv = Isometry(Point(
    vec4(0.5 * sqrt2 + 1., -0.5 * sqrt2 - 1., auxSurfaceP, -auxSurfaceP),
    -PI / 2.
    ));

    Isometry genB1 = Isometry(Point(
    vec4(0.5 * sqrt2 + 1., 0.5 * sqrt2 + 1., sqrt2 * auxSurfaceP, 0),
    PI / 2.
    ));

    Isometry genB1inv = Isometry(Point(
    vec4(0.5 * sqrt2 + 1., -0.5 * sqrt2 - 1., -sqrt2 * auxSurfaceP, 0),
    -PI / 2.
    ));

    Isometry genB2 = Isometry(Point(
    vec4(0.5 * sqrt2 + 1., 0.5 * sqrt2 + 1., -sqrt2 * auxSurfaceP, 0),
    PI / 2.
    ));

    Isometry genB2inv = Isometry(Point(
    vec4(0.5 * sqrt2 + 1., -0.5 * sqrt2 - 1., sqrt2 * auxSurfaceP, 0),
    -PI / 2.
    ));

    // translation by 2pi along the fiber
    Isometry genC = Isometry(Point(
    vec4(-1, 0, 0, 0),
    2. * PI
    ));

    // translation by -2pi along the fiber
    Isometry genCinv = Isometry(Point(
    vec4(-1, 0, 0, 0),
    - 2. * PI
    ));

    // testing if the point is in the fundamental domain, and the matrix to fix it
    float threshold = sqrt2 * auxSurfaceM;


    if (dot(klein, nh) > threshold) {
        fixIsom = genA1inv;
        return true;
    }
    if (dot(klein, nd1) > threshold) {
        fixIsom = genB1inv;
        return true;
    }
    if (dot(klein, nv) > threshold) {
        fixIsom = genA1;
        return true;
    }
    if (dot(klein, nd2) > threshold) {
        fixIsom = genB1;
        return true;
    }
    if (dot(klein, nh) < -threshold) {
        fixIsom = genA2inv;
        return true;
    }
    if (dot(klein, nd1) < -threshold) {
        fixIsom = genB2inv;
        return true;
    }
    if (dot(klein, nv) < -threshold) {
        fixIsom = genA2;
        return true;
    }
    if (dot(klein, nd2) < -threshold) {
        fixIsom = genB2;
        return true;
    }
    if (dot(klein, nfiber) > PI) {
        fixIsom = genCinv;
        return true;
    }
    if (dot(klein, nfiber) < -PI) {
        fixIsom = genC;
        return true;
    }

    return false;
}




bool isOutsideCell(Point p, out Isometry fixIsom){
    return isOutsideCellSurface(p, fixIsom);
}

// overload of the previous method with tangent vector
bool isOutsideCell(Vector v, out Isometry fixIsom){
    return isOutsideCell(v.pos, fixIsom);
}


//----------------------------------------------------------------------------------------------------------------------
// GEOM DEPENDENT
//----------------------------------------------------------------------------------------------------------------------


//NORMAL FUNCTIONS ++++++++++++++++++++++++++++++++++++++++++++++++++++
// the coordinates refer to a prefered basis, which is geometry dependent
// Remi : NOW GEOMETRY INDEPENDENT...
Vector estimateNormal(Point p) {
    //float newEp = EPSILON * 10.0;
    float newEp = 0.01;

    Point shiftPX = smallShift(p, vec3(newEp, 0, 0));
    Point shiftPY = smallShift(p, vec3(0, newEp, 0));
    Point shiftPZ = smallShift(p, vec3(0, 0, newEp));
    Point shiftMX = smallShift(p, vec3(-newEp, 0, 0));
    Point shiftMY = smallShift(p, vec3(0, -newEp, 0));
    Point shiftMZ = smallShift(p, vec3(0, 0, -newEp));

    Vector n;

    if (hitWhich != 3){
        // little hack, otherwise the shader collaspe when there are too many objets in the scene.
        /*
        float ref = globalSceneSDF(p);
        float vgx = globalSceneSDF(shiftPX) - ref;
        float vgy = globalSceneSDF(shiftPY) - ref;
        float vgz = globalSceneSDF(shiftPZ) - ref;
        */
        //global light scene
        float vgx = globalSceneSDF(shiftPX) - globalSceneSDF(shiftMX);
        float vgy = globalSceneSDF(shiftPY) - globalSceneSDF(shiftMY);
        float vgz = globalSceneSDF(shiftPZ) - globalSceneSDF(shiftMZ);
        n = createVector(p, vec3(vgx, vgy, vgz));
    }
    else { //local scene
        n = createVector(p, vec3(
        localSceneSDF(shiftPX) - localSceneSDF(shiftMX),
        localSceneSDF(shiftPY) - localSceneSDF(shiftMY),
        localSceneSDF(shiftPZ) - localSceneSDF(shiftMZ)
        ));
    }
    n = tangNormalize(n);
    return n;
}


//----------------------------------------------------------------------------------------------------------------------
// DOING THE RAYMARCH
//----------------------------------------------------------------------------------------------------------------------


// raymarch algorithm
// each step is the march is made from the previously achieved position (useful later for Sol).
// done with general vectors


int BINARY_SEARCH_STEPS=10;

void raymarchIterate(Vector rayDir, out Isometry totalFixIsom){

    Isometry fixIsom;
    Isometry testfixIsom;
    float marchStep = MIN_DIST;
    float testMarchStep = MIN_DIST;
    float globalDepth = MIN_DIST;
    float localDepth = MIN_DIST;
    Vector tv = rayDir;
    Vector localtv = rayDir;
    Vector testlocaltv = rayDir;
    Vector bestlocaltv = rayDir;
    totalFixIsom = identity;

    // Trace the local scene, then the global scene:

    if (TILING_SCENE){
        for (int i = 0; i < MAX_MARCHING_STEPS; i++){
            localtv = flow(localtv, marchStep);
            if (isOutsideCell(localtv, fixIsom)){
                totalFixIsom = composeIsometry(fixIsom, totalFixIsom);
                localtv = translate(fixIsom, localtv);
                marchStep = MIN_DIST;
            }
            else {
                float localDist = min(1., localSceneSDF(localtv.pos));
                if (localDist < EPSILON){
                    sampletv = localtv;
                    break;
                }
                marchStep = localDist;
                globalDepth += localDist;
            }
        }

        localDepth=min(globalDepth, MAX_DIST);

        /*
        // TODO. VERSION TO BE CHECKED...
        for (int i = 0; i < MAX_MARCHING_STEPS; i++){
            float localDist = localSceneSDF(localtv.pos);


            if (localDist < EPSILON){
                sampletv = toTangVector(localtv);
                break;
            }
            marchStep = localDist;

            //localtv = flow(localtv, marchStep);

            //            if (isOutsideCell(localtv, fixIsom)){
            //                totalFixIsom = composeIsometry(fixIsom, totalFixIsom);
            //                localtv = translate(fixIsom, localtv);
            //                localtv=tangNormalize(localtv);
            //                marchStep = MIN_DIST;
            //            }

            testlocaltv = flow(localtv, marchStep);
            if (isOutsideCell(testlocaltv, fixIsom)){
                bestlocaltv = testlocaltv;

                for (int j = 0; j < BINARY_SEARCH_STEPS; j++){
                    ////// do binary search to get close to but outside this cell -
                    ////// dont jump too far forwards, since localSDF can't see stuff in the next cube
                    testMarchStep = marchStep - pow(0.5,float(j+1))*localDist;
                    testlocaltv = flow(localtv, testMarchStep);
                    if ( isOutsideCell(testlocaltv, testfixIsom) ){
                        marchStep = testMarchStep;
                        bestlocaltv = testlocaltv;
                        fixIsom = testfixIsom;
                    }
                }

                localtv = bestlocaltv;
                totalFixIsom = composeIsometry(fixIsom, totalFixIsom);
                localtv = translate(fixIsom, localtv);
                localtv=tangNormalize(localtv);
                //globalDepth += marchStep;
                marchStep = MIN_DIST;
            }

            else{
                localtv = testlocaltv;
                globalDepth += marchStep;
            }
        }
        localDepth=min(globalDepth, MAX_DIST);
        */

    }
    else {
        localDepth=MAX_DIST;
    }

    if (GLOBAL_SCENE){
        globalDepth = MIN_DIST;
        marchStep = MIN_DIST;

        for (int i = 0; i < MAX_MARCHING_STEPS; i++){
            tv = flow(tv, marchStep);

            /*
            if (i == 1) {
                float aux = globalSceneSDF(tv.pos);
                hitWhich = 5;
                //debugColor = 1000. * aux * vec3(1, 0, 0);
                debugColor = abs(tv.dir);
                break;
            }
            */

            float globalDist = globalSceneSDF(tv.pos);
            if (globalDist < EPSILON){
                // hitWhich has now been set
                totalFixIsom = identity;
                sampletv = tv;
                return;
            }
            marchStep = globalDist;
            globalDepth += globalDist;
            if (globalDepth >= localDepth){
                break;
            }
        }
    }
}


void raymarchDirect(Vector rayDir, out Isometry totalFixIsom){

    Isometry fixIsom;
    Isometry testFixIsom;
    float marchStep = MIN_DIST;
    float testMarchStep = MIN_DIST;
    float globalDepth = MIN_DIST;
    float localDepth = MIN_DIST;
    Vector tv = rayDir;
    Vector localtv = rayDir;
    Vector testlocaltv = rayDir;
    Vector bestlocaltv = rayDir;
    totalFixIsom = identity;

    // Trace the local scene, then the global scene:

    if (TILING_SCENE){
        /*
        // VERSION WITHOUT CREEPING
        for (int i = 0; i < MAX_MARCHING_STEPS; i++){
            localtv = flow(localtv, marchStep);
            if (isOutsideCell(localtv, fixIsom)){
                totalFixIsom = composeIsometry(fixIsom, totalFixIsom);
                localtv = translate(fixIsom, localtv);
                marchStep = MIN_DIST;
            }
            else {
                float localDist = min(1., localSceneSDF(localtv.pos));
                if (localDist < EPSILON){
                    sampletv = localtv;
                    break;
                }
                marchStep = localDist;
                globalDepth += localDist;
            }
        }

        localDepth=min(globalDepth, MAX_DIST);
        */

        // VERSION WITH CREEPING
        for (int i = 0; i < MAX_MARCHING_STEPS; i++){
            float localDist = localSceneSDF(localtv.pos);
            if (localDist < EPSILON){
                sampletv = localtv;
                //distToViewer=localDepth;
                break;
            }
            marchStep = localDist;

            testlocaltv = flow(localtv, marchStep);
            if (isOutsideCell(testlocaltv, fixIsom)){
                bestlocaltv = testlocaltv;

                //commenting out this for loop brings us back to what we were doing before...
                for (int j = 0; j < BINARY_SEARCH_STEPS; j++){
                    // do binary search to get close to but outside this cell -
                    // dont jump too far forwards, since localSDF can't see stuff in the next cube
                    testMarchStep = marchStep - pow(0.5, float(j+1))*localDist;
                    testlocaltv = flow(localtv, testMarchStep);
                    if (isOutsideCell(testlocaltv, testFixIsom)){
                        marchStep = testMarchStep;
                        bestlocaltv = testlocaltv;
                        fixIsom = testFixIsom;
                    }
                }
                localtv = bestlocaltv;
                totalFixIsom = composeIsometry(fixIsom, totalFixIsom);
                localtv = translate(fixIsom, localtv);
                localDepth += marchStep;
                marchStep = MIN_DIST;
            }

            else {
                localtv = testlocaltv;
                localDepth += marchStep;
            }
        }

        localDepth=min(localDepth, MAX_DIST);


    }
    else {
        localDepth=MAX_DIST;
    }

    if (GLOBAL_SCENE){
        globalDepth = MIN_DIST;
        marchStep = MIN_DIST;

        for (int i = 0; i < MAX_MARCHING_STEPS; i++){
            tv = flow(rayDir, globalDepth);

            /*
            if (i == 2) {
                //float aux = globalSceneSDF(tv.pos);
                hitWhich = 5;
                //debugColor = 1000. * aux * vec3(1, 0, 0);
                debugColor = vec3(tv.pos.fiber, -tv.pos.fiber,0);
                break;
            }
            */


            float globalDist = globalSceneSDF(tv.pos);
            if (globalDist < EPSILON){
                // hitWhich has now been set
                hitWhich = 5;
                debugColor = vec3(tv.pos.fiber, -tv.pos.fiber, 0);
                totalFixIsom = identity;
                sampletv = tv;
                return;
            }
            //marchStep = globalDist;
            globalDepth += globalDist;
            if (globalDepth >= localDepth){
                break;
            }
        }
    }
}


void raymarch(Vector rayDir, out Isometry totalFixIsom){
    //raymarchIterate(rayDir, totalFixIsom);
    raymarchDirect(rayDir, totalFixIsom);
}


//----------------------------------------------------------------------------------------------------------------------
//Geometry of the Models
//----------------------------------------------------------------------------------------------------------------------

/*
TODO. Check if needed in general ? Geometry dependent ?
*/

//project point back onto the geometry
Point geomProject(Point p){
    return p;
}

//Project onto the Klein Model
Point modelProject(Point p){
    return p;

}

//----------------------------------------------------------------------------------------------------------------------
// Lighting Functions
//----------------------------------------------------------------------------------------------------------------------
//SP - Sample Point | TLP - Translated Light Position | V - View Vector
vec3 lightingCalculations(Point SP, Point TLP, Vector V, vec3 baseColor, vec4 lightIntensity){
    // Distance to the light
    // Small hack:
    // if the light is too far (and the related computations could create numerical erroe such as nan),
    // then we simply ignore it
    float distToLight = fakeDistance(SP, TLP);

    if (distToLight < 1000.) {
        //Calculations - Phong Reflection Model
        Vector L = tangDirection(SP, TLP);
        Vector R = sub(scalarMult(2.0 * cosAng(L, N), N), L);
        //Calculate Diffuse Component
        float nDotL = max(cosAng(N, L), 0.0);
        vec3 diffuse = lightIntensity.rgb * nDotL;
        //Calculate Specular Component
        float rDotV = max(cosAng(R, V), 0.0);
        vec3 specular = lightIntensity.rgb * pow(rDotV, 10.0);
        //Attenuation - Of the Light Intensity

        float att = 0.6 * lightIntensity.w / (0.01 + lightAtt(distToLight));
        //Compute final color

        // DEBUGGING
        return att*((diffuse*baseColor) + specular);
        //return L.dir;
        //return vec3(distToLight);
    }
    else {
        return vec3(0);
    }


}

vec3 phongModel(Isometry totalFixIsom, vec3 color){
    Point SP = sampletv.pos;
    Point TLP;//translated light position
    Vector V = turnAround(sampletv);

    vec3 surfColor;
    surfColor = 0.2 * vec3(1.) + 0.8 * color;

    if (display == 3 || display == 4){ //for the dragon skin one only
        surfColor = 0.7 * vec3(1.) + 0.3 * color;//make it brighter when there's less stuff
    }
    //    vec3 color = vec3(0.0);
    //--------------------------------------------------
    //Lighting Calculations
    //--------------------------------------------------
    //usually we'd check to ensure there are 4 lights
    //however this is version is hardcoded so we won't

    //GLOBAL LIGHTS THAT WE DONT ACTUALLY RENDER

    // DEBUGGING
    /*
    int i = 0;
    Isometry totalIsom = composeIsometry(totalFixIsom, invCellBoost);
    TLP = translate(totalIsom, unserializePoint(lightPositions[i]));
    color = lightingCalculations(SP, TLP, V, surfColor, lightIntensities[i]);
    */


    for (int i = 0; i<4; i++){
        Isometry totalIsom = composeIsometry(totalFixIsom, invCellBoost);
        TLP = translate(totalIsom, unserializePoint(lightPositions[i]));
        color += lightingCalculations(SP, TLP, V, surfColor, lightIntensities[i]);
    }


    //LOCAL LIGHT
    //color += lightingCalculations(SP, localLightPos, V, surfColor, localLightColor);
    color += 2. * lightingCalculations(SP, localLightPos, V, surfColor, localLightColor);
    //light color and intensity hard coded in

    /*
    //move local light around by the generators to pick up lighting from nearby cells
    for (int i=0; i<6; i++){
        //TLP=invGenerators[i]*localLightPos;
        TLP = translate(unserializeIsom(invGenerators[i]), localLightPos);
        color+= lightingCalculations(SP, TLP, V, surfColor, localLightColor);
    }
    */

    return color;
}


//EARTH TEXTURING COLOR COMMANDS

// return the two smallest numbers in a triplet
vec2 smallest(vec3 v)
{
    float mi = min(v.x, min(v.y, v.z));
    float ma = max(v.x, max(v.y, v.z));
    float me = v.x + v.y + v.z - mi - ma;
    return vec2(mi, me);
}

/*
// texture a 4D surface by doing 4 2D projections in the most
// perpendicular possible directions, and then blend them
// together based on the surface normal
// TODO. Check with Steve how to make this part geometry independent.
vec3 boxMapping(sampler2D sam, Vector point)
{ // from Inigo Quilez
    vec4 m = point.dir * point.dir; m=m*m; m=m*m;

    vec3 x = texture(sam, smallest(point.pos.yzw)).xyz;
    vec3 y = texture(sam, smallest(point.pos.zwx)).xyz;
    vec3 z = texture(sam, smallest(point.pos.wxy)).xyz;
    vec3 w = texture(sam, smallest(point.pos.xyz)).xyz;

    return (x*m.x + y*m.y + z*m.z + w*m.w)/(m.x+m.y+m.z+m.w);
}

// TODO. Rémi: not sure what it does.
vec3 sphereOffset(Isometry globalObjectBoost, vec4 pt){
    pt = translate(cellBoost, pt);
    Isometry aux = makeInvLeftTranslation(globalObjectBoostMat);
    pt = translate(aux, pt);
    return tangDirection(ORIGIN, pt).global_dir.xyz;
}*/

vec3 lightColor(Isometry totalFixIsom, Vector sampletv, vec3  colorOfLight){
    N = estimateNormal(sampletv.pos);
    vec3 color;
    color = phongModel(totalFixIsom, 0.5 * colorOfLight);
    color = 0.7 * color + 0.3;
    return color;
}

vec3 ballColor(Isometry totalFixIsom, Vector sampletv){
    /*
    if (EARTH){
        N = estimateNormal(sampletv.pos);
        vec3 color = texture(earthCubeTex, sphereOffset(globalObjectBoost, sampletv.pos)).xyz;
        vec3 color2 = phongModel(totalFixIsom, color);
        //color = 0.9*color+0.1;
        return 0.5 * color + 0.5 * color2;
    }
    else */
    {

        N = estimateNormal(sampletv.pos);
        vec3 color=localLightColor.xyz;
        color = phongModel(totalFixIsom, 0.5 * color);
        color = 0.7*color+0.3;
        return color;


        //generically gray object (color= black, glowing slightly because of the 0.1)
    }

}


vec3 tilingColor(Isometry totalFixIsom, Vector sampletv){
    //    if (FAKE_LIGHT){//always fake light in Sol so far

    //make the objects have their own color
    //color the object based on its position in the cube
    Point samplePos=modelProject(sampletv.pos);

    /*
    vec4 aux4 = abs(toVec4(samplePos));
    vec3 color = abs(tanh(aux4.xyw));
    //vec3 color = 1.1 * aux4.xyw / length(aux4.xyw);
    */

    //IF WE HIT THE TILING
    vec4 aux = toVec4(samplePos);
    float x=aux.x;
    float y=aux.y;
    float z=aux.z;
    x = 0.9 * x / modelHalfCube;
    y = 0.9 * y / modelHalfCube;
    z = 0.9 * z / modelHalfCube;
    vec3 color = vec3(x, y, z);


    N = estimateNormal(sampletv.pos);
    color = phongModel(totalFixIsom, 0.1*color);

    return 0.9*color+0.1;

    //adding a small constant makes it glow slightly
    //}
    //    else {
    //        //if we are doing TRUE LIGHTING
    //        // objects have no natural color, only lit by the lights
    //        N = estimateNormal(sampletv.pos);
    //        vec3 color=vec3(0., 0., 0.);
    //        color = phongModel(totalFixIsom, color);
    //        return color;
    //    }
}


//----------------------------------------------------------------------------------------------------------------------
// Tangent Space Functions
//----------------------------------------------------------------------------------------------------------------------

Vector getRayPoint(vec2 resolution, vec2 fragCoord, bool isLeft){ //creates a tangent vector for our ray
    if (isStereo == 1){
        resolution.x = resolution.x * 0.5;
        if (!isLeft) { fragCoord.x = fragCoord.x - resolution.x; }
    }
    vec2 xy = 0.2 * ((fragCoord - 0.5*resolution)/resolution.x);
    float z = 0.1 / tan(radians(fov * 0.5));
    // coordinates in the prefered frame at the origin
    vec3 dir = vec3(xy, -z);
    Vector tv = createVector(ORIGIN, dir);
    tv = tangNormalize(tv);
    return tv;
}

//----------------------------------------------------------------------------------------------------------------------
// Main
//----------------------------------------------------------------------------------------------------------------------

Vector doNothing(Vector v){
    return v;
}

void main(){
    setResolution(resol);
    currentBoost = unserializeIsom(currentBoostMat);
    leftBoost = unserializeIsom(leftBoostMat);
    rightBoost = unserializeIsom(rightBoostMat);
    cellBoost = unserializeIsom(cellBoostMat);
    invCellBoost = unserializeIsom(invCellBoostMat);
    globalObjectBoost = unserializeIsom(globalObjectBoostMat);

    localLightPos = fromVec4(vec4(0.1, 0.1, -0.2, 1.));


    //stereo translations ----------------------------------------------------
    bool isLeft = gl_FragCoord.x/screenResolution.x <= 0.5;
    Vector rayDir = getRayPoint(screenResolution, gl_FragCoord.xy, isLeft);



    if (isStereo == 1){
        if (isLeft){
            //rayDir = doNothing(rayDir);
            rayDir = rotateByFacing(leftFacing, rayDir);
            rayDir = translate(leftBoost, rayDir);
        }
        else {
            rayDir = rotateByFacing(rightFacing, rayDir);
            rayDir = translate(rightBoost, rayDir);
        }
    }
    else {
        //debugColor = vec3(0, 1, 1);
        rayDir = rotateByFacing(facing, rayDir);
        rayDir = translate(currentBoost, rayDir);
    }


    hitWhich = 5;
    //rayDir = rotateByFacing(facing, rayDir);
    Isometry shift = makeInvLeftTranslation(rayDir.pos);
    mat4 test = SLtoMatrix4(shift.target.proj);

    //debugColor = length(shift.target.proj - ORIGIN.proj) * vec3(1);
    //debugColor = abs(shift.target.fiber - ORIGIN.fiber) * vec3(1);
    //debugColor = 0.9*res[1].xyz;
    debugColor = length(test[1] - vec4(0, 1, 0, 0)) * vec3(1, 1, 1);



    out_FragColor = vec4(debugColor, 1.0);
    //get our raymarched distance back ------------------------

/*


    Isometry totalFixIsom = identity;

    //do the marching
    raymarch(rayDir, totalFixIsom);


    vec3 pixelColor;
    //Based on hitWhich decide whether we hit a global object, local object, or nothing
    switch (hitWhich){
        case 0://Didn't hit anything
        //COLOR THE FRAME DARK GRAY
        //0.2 is medium gray, 0 is black
        out_FragColor = vec4(0.4);
        break;

        case 1:// global lights
        pixelColor= lightColor(totalFixIsom, sampletv, colorOfLight);
        //out_FragColor=vec4(pixelColor, 1.0);
        out_FragColor = vec4(colorOfLight, 1.0);
        break;

        case 2:// global object
        pixelColor= ballColor(totalFixIsom, sampletv);
        //debugColor = abs(N.dir);
        //pixelColor = debugColor;
        out_FragColor=vec4(pixelColor, 1.0);
        break;

        case 3:// local objects
        pixelColor= tilingColor(totalFixIsom, sampletv);
        out_FragColor=vec4(pixelColor, 1.0);
        break;

        case 5:
        //debug
        out_FragColor = vec4(debugColor, 1.0);
        break;
    }
*/


}
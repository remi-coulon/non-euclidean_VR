#version 300 es
out vec4 out_FragColor;


//--------------------------------------------
// PARAMETERS
//--------------------------------------------

/*

Some parameters that can be changed to change the scence

*/
const bool FAKE_LIGHT_FALLOFF=true;
const bool SURFACE_COLOR=true;
const bool FAKE_LIGHT = true;
const bool FAKE_DIST_SPHERE = false;
const float globalObjectRadius = 0.1;
const float centerSphereRadius =1.;
const float vertexSphereSize = -0.95;//In this case its a horosphere

//--------------------------------------------
// "TRUE" CONSTANTS
//--------------------------------------------

const float PI = 3.1415926538;

const vec4 ORIGIN = vec4(0, 0, 0, 1);
const float modelHalfCube =  0.5773502692;//projection of cube to klein model
const vec4 modelCubeCorner = vec4(modelHalfCube, modelHalfCube, modelHalfCube, 1.0);//corner of cube in Klein model, useful for horosphere distance function
/*
//generated in JS using translateByVector(new THREE.Vector3(-c_ipDist,0,0));
const mat4 leftBoost = mat4(1.000512043692158,0.,0.,0.03200546161296042,
0.,1.,0.,0.,
0.,0.,1.,0.,
 0.03200546161296042, 0.,0.,1.000512043692158);

//generated in JS using translateByVector(new THREE.Vector3(c_ipDist,0,0));
const mat4 rightBoost = mat4(1.000512043692158,0.,0.,-0.03200546161296042,
0.,1.,0.,0.,
0.,0.,1.,0.,
 -0.03200546161296042, 0.,0.,1.000512043692158);
*/

vec3 debugColor = vec3(0.5, 0, 0.8);

//--------------------------------------------
// AUXILIARY (BASICS)
//--------------------------------------------




//--------------------------------------------
// STRUCT tangVector
//--------------------------------------------

/*
  Data type for manipulating points in the tangent bundler
  A tangVector is given by
  - pos : a point in the space
  - dir: a tangent vector at pos

  Implement various basic methods to manipulate them
*/

struct tangVector {
    vec4 pos;// position on the manifold
    vec4 dir;// vector in the tangent space at the point pos
};



//--------------------------------------------
// STRUCT isom
//--------------------------------------------

/*
  Data type for storing isometries of the space
  An isom is given by (in hyperbolic space)
  - mat : a matrix*/

struct isom {
    mat4 matrix;// position on the manifold
};

// use this in H2xR, S2xR for cases where the isometries have matrix and real number components.


//--------------------------------------------
// LOCAL GEOMETRY
//--------------------------------------------

/*
  Methods perfoming computations in the tangent space at a given point.
*/

tangVector add(tangVector v1, tangVector v2) {
    // add two tangent vector at the same point
    // TODO : check if the underlyig point are indeed the same ?
    return tangVector(v1.pos, v1.dir + v2.dir);
}

tangVector sub(tangVector v1, tangVector v2) {
    // subtract two tangent vector at the same point
    // TODO : check if the underlyig point are indeed the same ?
    return tangVector(v1.pos, v1.dir - v2.dir);
}

tangVector scalarMult(float a, tangVector v) {
    // scalar multiplication of a tangent vector
    return tangVector(v.pos, a * v.dir);
}



float tangDot(tangVector u, tangVector v){
  
    mat4 g = mat4(
    1.,0.,0.,0.,
    0.,1.,0.,0.,
    0.,0.,1.,0.,
    0.,0.,0.,-1.
    );

    return dot(u.dir,  g*v.dir);

}

float tangNorm(tangVector v){
    // calculate the length of a tangent vector
    return sqrt(abs(tangDot(v, v)));
}

tangVector tangNormalize(tangVector v){
    // create a unit tangent vector (in the tangle bundle)
    return tangVector(v.pos, v.dir/tangNorm(v));
}

float cosAng(tangVector u, tangVector v){
    // cosAng between two vector in the tangent bundle
    return tangDot(u, v);
}


mat4 tangBasis(vec4 p){
    // return a basis of vectors at the point p

    tangVector basis_x = tangVector(p, vec4(p.w, 0.0, 0.0, p.x));
    tangVector basis_y = tangVector(p, vec4(0.0, p.w, 0.0, p.y));
    tangVector basis_z = 
        tangVector(p,vec4(0.0, 0.0, p.w, p.z));
    //make this orthonormal
   basis_x=tangNormalize(basis_x);                                
   basis_y = tangNormalize(
    sub(basis_y, 
        scalarMult(tangDot(basis_y, basis_x),basis_x)));// need to Gram Schmidt
    basis_z = tangNormalize(
        sub(basis_z,
            sub(scalarMult(tangDot( basis_z, basis_x),basis_x), scalarMult(tangDot( basis_z, basis_y),basis_y))));
//                            
    mat4 theBasis=mat4(0.);
    
    theBasis[0]=basis_x.dir;
    theBasis[1]=basis_y.dir;
    theBasis[2]=basis_z.dir;
    return theBasis;
}






//--------------------------------------------
// ISOMETRIES & TANGENT BUNDLE
//--------------------------------------------

/*
tangVector applyIsom(mat4 A, tangVector v) {
    // apply an isometry to the tangent vector (both the point and the direction)
    return tangVector(A * v.pos, A* v.dir);
}
*/

isom composeIsom(isom A, isom B){
    return isom(A.matrix*B.matrix);
}

tangVector applyIsom(isom A, tangVector v) {
    // apply an isometry to the tangent vector (both the point and the direction)
    return tangVector(A.matrix * v.pos, A.matrix * v.dir);
}

vec4 applyIsom(isom A, vec4 v) {
    // overload for when only applied to a point
    return A.matrix * v.pos;
}


tangVector changeFacing(mat4 matrix, tangVector v) {
    // apply the given given matrix only to the direction of the tangent vector
    return tangVector(v.pos, matrix* v.dir);
}








//--------------------------------------------
// GLOBAL GEOMETRY
//--------------------------------------------

/*
  Methods computing ``global'' objects
*/

float hypAng(vec4 p, vec4 q){
        //negative the lorentz dot product gives the hyperbolic angle between the two points
    return -p.x*q.x-p.y*q.y-p.z*q.z+p.w*q.w;
}

float fakeDistance(vec4 p, vec4 q){
    // measure the distance between two points in the geometry
    // fake distance
    return acosh(hypAng(p,q));
}

float fakeDistance(tangVector u, tangVector v){
    // overload of the previous function in case we work with tangent vectors
    return fakeDistance(u.pos, v.pos);
}

float exactDist(vec4 p, vec4 q) {
    // move p to the origin
   return acosh(hypAng(p,q));
}

float exactDist(tangVector u, tangVector v){
    // overload of the previous function in case we work with tangent vectors
    return exactDist(u.pos, v.pos);
}

tangVector tangDirection(vec4 p, vec4 q){
    // return the unit tangent to geodesic connecting p to q.
        return tangNormalize(tangVector(p, q - hypAng(p,q)*p));
}

tangVector tangDirection(tangVector u, tangVector v){
    // overload of the previous function in case we work with tangent vectors
     return tangDirection(u.pos, v.pos);
}

tangVector flow(tangVector tv, float t){
    // follow the geodesic flow during a time t
    vec4 resPos=tv.pos*cosh(t) + tv.dir*sinh(t);
    //tangent is derivative of position
    vec4 resDir=tv.pos*sinh(t) + tv.dir*cosh(t);

    return tangVector(resPos,resDir);
}


//--------------------------------------------
//Geometry of the Models
//--------------------------------------------


//project point back onto the geometry
vec4 geomProject(vec4 p){
    return p/sqrt(abs(hypAng(p,p)));
}


//Project onto the Klein Model
vec4 modelProject(vec4 p){
    return p/p.w;
 
}


//-------------------------------------------------------
// LIGHT
//-------------------------------------------------------
//light intensity as a fn of distance
float lightAtt(float dist){
    if(FAKE_LIGHT_FALLOFF){
           //fake linear falloff
    return dist;
    }
 return sinh(dist)*sinh(dist);
}


//---------------------------------------------------------------------
//Raymarch Primitives
//---------------------------------------------------------------------


float sphereSDF(vec4 p, vec4 center, float radius){
            return exactDist(p, center) - radius;
      
}


  // A horosphere can be constructed by offseting from a standard horosphere.
  // Our standard horosphere will have a center in the direction of lightPoint
  // and go through the origin. Negative offsets will shrink it.
  float horosphereSDF(vec4 samplePoint, vec4 lightPoint, float offset){
    return log(-hypAng(samplePoint, lightPoint)) - offset;
  }


float centerSDF(vec4 p, vec4 center, float radius){
    return sphereSDF(p, center, radius);
}


float vertexSDF(vec4 p, vec4 cornerPoint, float size){
    return  horosphereSDF(p, cornerPoint, size);
}

//--------------------------------------------
//Global Constants
//--------------------------------------------
const int MAX_MARCHING_STEPS =  80;
const float MIN_DIST = 0.0;
const float MAX_DIST = 200.0;
const float EPSILON = 0.0001;
const float fov = 90.0;
const float sqrt3 = 1.7320508075688772;


//--------------------------------------------
//Global Variables
//--------------------------------------------
tangVector N;//normal vector
tangVector sampletv;
vec4 globalLightColor;
int hitWhich = 0;
isom currentBoost;
isom leftBoost;
isom rightBoost;
isom cellBoost;
isom invCellBoost;
//-------------------------------------------
//Translation & Utility Variables
//--------------------------------------------
uniform int isStereo;
uniform vec2 screenResolution;
uniform mat4 invGenerators[6];  //NEED TO UPDATE TO ISOM 
uniform mat4 currentBoostMat;
uniform mat4 leftBoostMat;
uniform mat4 rightBoostMat;
uniform mat4 facing;
uniform mat4 leftFacing;
uniform mat4 rightFacing;
uniform mat4 cellBoostMat;
uniform mat4 invCellBoostMat;
//--------------------------------------------
// Lighting Variables & Global Object Variables
//--------------------------------------------
uniform vec4 lightPositions[4];
uniform vec4 lightIntensities[4];
uniform mat4 globalObjectBoost;

//--------------------------------------------
// Building things from our uniforms
//--------------------------------------------
currentBoost = isom(currentBoostMat);
leftBoost = isom(leftBoostMat);
rightBoost = isom(rightBoostMat);
cellBoost = isom(cellBoostMat);
invCellBoost = isom(invCellBoostMat);

//---------------------------------------------------------------------
// Scene Definitions
//---------------------------------------------------------------------
// Turn off the local scene
// Local signed distance function : distance from p to an object in the local scene

float localSceneSDF(vec4 p){
    vec4 center = vec4(0, 0, 0., 1.);
    float sphere = centerSDF(p,  center, centerSphereRadius);
    float vertexSphere = 0.0;
    vertexSphere = vertexSDF(abs(p), modelCubeCorner, vertexSphereSize);
    float final = -min(vertexSphere,sphere); //unionSDF
    return final;
    
   // float final = -sphere;
    //return final;
}

//GLOBAL OBJECTS SCENE ++++++++++++++++++++++++++++++++++++++++++++++++
// Global signed distance function : distance from cellBoost * p to an object in the global scene
float globalSceneSDF(vec4 p){
    vec4 absolutep = applyIsom(cellBoost, p);// correct for the fact that we have been moving
    float distance = MAX_DIST;
    //Light Objects
    for (int i=0; i<4; i++){
        float objDist;
        objDist = sphereSDF(
        absolutep,
        lightPositions[i],
        1.0/(10.0*lightIntensities[i].w)
        );
        distance = min(distance, objDist);
        if (distance < EPSILON){
            hitWhich = 1;
            globalLightColor = lightIntensities[i];
            return distance;
        }
    }
    //Global Sphere Object
    float objDist;
    objDist = sphereSDF(absolutep, globalObjectBoost[3], globalObjectRadius);
    distance = min(distance, objDist);
    if (distance < EPSILON){
        hitWhich = 2;
    }
    return distance;
}


// check if the given point p is in the fundamental domain of the lattice.
bool isOutsideCell(vec4 p, out mat4 fixMatrix){
    vec4 ModelP= modelProject(p);
    if (ModelP.x > modelHalfCube){
        fixMatrix = invGenerators[0];
        return true;
    }
    if (ModelP.x < -modelHalfCube){
        fixMatrix = invGenerators[1];
        return true;
    }
    if (ModelP.y > modelHalfCube){
        fixMatrix = invGenerators[2];
        return true;
    }
    if (ModelP.y < -modelHalfCube){
        fixMatrix = invGenerators[3];
        return true;
    }
    if (ModelP.z > modelHalfCube){
        fixMatrix = invGenerators[4];
        return true;
    }
    if (ModelP.z < -modelHalfCube){
        fixMatrix = invGenerators[5];
        return true;
    }
    return false;
}



// overload of the previous method with tangent vector
bool isOutsideCell(tangVector v, out mat4 fixMatrix){
    return isOutsideCell(v.pos, fixMatrix);
}


//--------------------------------------------
// GEOM DEPENDENT
//--------------------------------------------


//NORMAL FUNCTIONS ++++++++++++++++++++++++++++++++++++++++++++++++++++
tangVector estimateNormal(vec4 p) { // normal vector is in tangent hyperplane to hyperboloid at p
    // float denom = sqrt(1.0 + p.x*p.x + p.y*p.y + p.z*p.z);  // first, find basis for that tangent hyperplane
    float newEp = EPSILON * 10.0;
    mat4 theBasis= tangBasis(p);
    vec4 basis_x = theBasis[0];
    vec4 basis_y = theBasis[1];
    vec4 basis_z = theBasis[2];
    if (hitWhich != 3){ //global light scene
        //p+EPSILON * basis_x should be lorentz normalized however it is close enough to be good enough
        tangVector tv = tangVector(p,
        basis_x * (globalSceneSDF(p + newEp*basis_x) - globalSceneSDF(p - newEp*basis_x)) +
        basis_y * (globalSceneSDF(p + newEp*basis_y) - globalSceneSDF(p - newEp*basis_y)) +
        basis_z * (globalSceneSDF(p + newEp*basis_z) - globalSceneSDF(p - newEp*basis_z))
        );
        return tangNormalize(tv);

    }
    else { //local scene
        tangVector tv = tangVector(p,
        basis_x * (localSceneSDF(p + newEp*basis_x) - localSceneSDF(p - newEp*basis_x)) +
        basis_y * (localSceneSDF(p + newEp*basis_y) - localSceneSDF(p - newEp*basis_y)) +
        basis_z * (localSceneSDF(p + newEp*basis_z) - localSceneSDF(p - newEp*basis_z))
        );
        return tangNormalize(tv);
    }
}


//--------------------------------------------
// DOING THE RAYMARCH
//--------------------------------------------


// variation on the raymarch algorithm
// now each step is the march is made from the previously achieved position (useful later for Sol).

void raymarch(tangVector rayDir, out mat4 totalFixMatrix){
    mat4 fixMatrix;
    float marchStep = MIN_DIST;
    float globalDepth = MIN_DIST;
    float localDepth = MIN_DIST;
    tangVector tv = rayDir;
    tangVector localtv = rayDir;
    totalFixMatrix = mat4(1.0);


    // Trace the local scene, then the global scene:
    for (int i = 0; i < MAX_MARCHING_STEPS; i++){
        localtv = flow(localtv, marchStep);

        if (isOutsideCell(localtv, fixMatrix)){
            totalFixMatrix = fixMatrix * totalFixMatrix;
            localtv = applyIsom(fixMatrix, localtv);
            marchStep = MIN_DIST;
        }
        else {
            float localDist = min(0.1, localSceneSDF(localtv.pos));
            if (localDist < EPSILON){
                hitWhich = 3;
                sampletv = localtv;
                break;
            }
            marchStep = localDist;
            globalDepth += localDist;
        }
    }

    // Set for localDepth to our new max tracing distance:
    localDepth = min(globalDepth, MAX_DIST);
    globalDepth = MIN_DIST;
    marchStep = MIN_DIST;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++){
        tv = flow(tv, marchStep);

        float globalDist = globalSceneSDF(tv.pos);
        if (globalDist < EPSILON){
            // hitWhich has now been set
            totalFixMatrix = mat4(1.0);
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


//void raymarch(tangVector rayDir, out mat4 totalFixMatrix){
//    mat4 fixMatrix;
//    float globalDepth = MIN_DIST;
//    float localDepth = MIN_DIST;
//    tangVector tv = rayDir;
//    tangVector localtv = rayDir;
//    totalFixMatrix = mat4(1.0);
//
//
//    // Trace the local scene, then the global scene:
//    for (int i = 0; i < MAX_MARCHING_STEPS; i++){
//        tangVector localEndtv = flow(localtv, localDepth);
//
//        if (isOutsideCell(localEndtv, fixMatrix)){
//            totalFixMatrix = fixMatrix * totalFixMatrix;
//            localtv = translate(fixMatrix, localEndtv);
//            localDepth = MIN_DIST;
//        }
//        else {
//            float localDist = min(0.1, localSceneSDF(localEndtv.pos));
//            if (localDist < EPSILON){
//                hitWhich = 3;
//                sampletv = localEndtv;
//                break;
//            }
//            localDepth += localDist;
//            globalDepth += localDist;
//        }
//    }
//
//
//    // Set for localDepth to our new max tracing distance:
//    localDepth = min(globalDepth, MAX_DIST);
//    globalDepth = MIN_DIST;
//    for (int i = 0; i < MAX_MARCHING_STEPS; i++){
//        tangVector globalEndtv = flow(tv, globalDepth);
//
//        float globalDist = globalSceneSDF(globalEndtv.pos);
//        if (globalDist < EPSILON){
//            // hitWhich has now been set
//            totalFixMatrix = mat4(1.0);
//            sampletv = globalEndtv;
//            return;
//        }
//        globalDepth += globalDist;
//        if (globalDepth >= localDepth){
//            break;
//        }
//    }
//}


//--------------------------------------------------------------------
// Lighting Functions
//--------------------------------------------------------------------
//SP - Sample Point | TLP - Translated Light Position | V - View Vector
vec3 lightingCalculations(vec4 SP, vec4 TLP, tangVector V, vec3 baseColor, vec4 lightIntensity){
    //Calculations - Phong Reflection Model
    tangVector L = tangDirection(SP, TLP);
    tangVector R = sub(scalarMult(2.0 * cosAng(L, N), N), L);
    //Calculate Diffuse Component
    float nDotL = max(cosAng(N, L), 0.0);
    vec3 diffuse = lightIntensity.rgb * nDotL;
    //Calculate Specular Component
    float rDotV = max(cosAng(R, V), 0.0);
    vec3 specular = lightIntensity.rgb * pow(rDotV, 10.0);
    //Attenuation - Of the Light Intensity
    float distToLight = fakeDistance(SP, TLP);
    float att = 0.6*lightIntensity.w /(0.01 + lightAtt(distToLight));
    //Compute final color
    return att*((diffuse*baseColor) + specular);
}

vec3 phongModel(mat4 totalFixMatrix, vec3 color){
    vec4 SP = sampletv.pos;
    vec4 TLP;//translated light position
    tangVector V = tangVector(SP, -sampletv.dir);
    //    vec3 color = vec3(0.0);
    //--------------------------------------------------
    //Lighting Calculations
    //--------------------------------------------------
    //usually we'd check to ensure there are 4 lights
    //however this is version is hardcoded so we won't
    for (int i = 0; i<4; i++){
        mat4 transf=composeIsom(totalFixMatrix,invCellBoost);
        TLP = applyIsom(transf,lightPositions[i]);
        color += lightingCalculations(SP, TLP, V, vec3(1.0), lightIntensities[i]);
    }
    return color;
}





vec3 localColor(mat4 totalFixMatrix, tangVector sampletv){
    N = estimateNormal(sampletv.pos);
        vec3 color=vec3(0.,0.,0.);
        color = phongModel(totalFixMatrix, color);
        color = 0.9*color+0.1;
        return color;
        //generically gray object (color= black, glowing slightly because of the 0.1)
}


vec3 globalColor(mat4 totalFixMatrix, tangVector sampletv){
     if(SURFACE_COLOR){//color the object based on its position in the cube
    vec4 samplePos=modelProject(sampletv.pos);
        //Point in the Klein Model unit cube    
        float x=samplePos.x;
        float y=samplePos.y;
        float z=samplePos.z;
        x = 0.9*x/modelHalfCube;    
        y = 0.9*y/modelHalfCube; 
        z = 0.9*z/modelHalfCube;   
        vec3 color = vec3(x,y,z);
        N = estimateNormal(sampletv.pos);
        color = phongModel(totalFixMatrix, 0.1*color);
        return 0.9*color+0.1;
        //adding a small constant makes it glow slightly
     }
    else{
            // objects
        N = estimateNormal(sampletv.pos);
        vec3 color=vec3(0.,0.,0.);
        color = phongModel(totalFixMatrix, color);
        return color;
        }
}
        
    





//--------------------------------------------------------------------
// Tangent Space Functions
//--------------------------------------------------------------------

tangVector getRayPoint(vec2 resolution, vec2 fragCoord, bool isLeft){ //creates a tangent vector for our ray
    if (isStereo == 1){
        resolution.x = resolution.x * 0.5;
        if (!isLeft) { fragCoord.x = fragCoord.x - resolution.x; }
    }
    vec2 xy = 0.2*((fragCoord - 0.5*resolution)/resolution.x);
    float z = 0.1/tan(radians(fov*0.5));
    tangVector tv = tangVector(ORIGIN, vec4(xy, -z, 0.0));
    tangVector v =  tangNormalize(tv);
    return v;
}

//--------------------------------------------------------------------
// Main
//--------------------------------------------------------------------

void main(){
    //vec4 rayOrigin = ORIGIN;

    //stereo translations ----------------------------------------------------
    bool isLeft = gl_FragCoord.x/screenResolution.x <= 0.5;
    tangVector rayDir = getRayPoint(screenResolution, gl_FragCoord.xy, isLeft);
    
        //camera position must be translated in hyperboloid -----------------------
    rayDir=changeFacing(facing, rayDir);
    
    
    if (isStereo == 1){
         
    
        if (isLeft){
            rayDir=changeFacing(leftFacing, rayDir);
            rayDir = applyIsom(leftBoost, rayDir);
        }
        else {
            rayDir=changeFacing(rightFacing, rayDir);
            rayDir = applyIsom(rightBoost, rayDir);
        }
    }

    
  // in other geometries, the facing will not be an isom, so applying facing is probably not good.
   // rayDir = translate(facing, rayDir);
    rayDir = applyIsom(currentBoost, rayDir);
    //generate direction then transform to hyperboloid ------------------------
    
    //    vec4 rayDirVPrime = tangDirection(rayOrigin, rayDirV);
    //get our raymarched distance back ------------------------
    mat4 totalFixMatrix = mat4(1.0);
    raymarch(rayDir, totalFixMatrix);

    //Based on hitWhich decide whether we hit a global object, local object, or nothing
    if (hitWhich == 0){ //Didn't hit anything ------------------------
        //COLOR THE FRAME DARK GRAY
        //0.2 is medium gray, 0 is black
        out_FragColor = vec4(0.2);
        return;
    }
    else if (hitWhich == 1){ // global lights
        out_FragColor = vec4(globalLightColor.rgb, 1.0);
        return;
    }
    else if (hitWhich == 5){ //debug
        out_FragColor = vec4(debugColor, 1.0);
    }
    
        else if (hitWhich == 2){ // global object
            
        vec3 pixelColor=localColor(totalFixMatrix, sampletv);
            
        out_FragColor = vec4( pixelColor,1.0);
            
        return;
    }
    
    else { // objects
        
        vec3 pixelColor= globalColor(totalFixMatrix, sampletv);
        
        out_FragColor=vec4(pixelColor,1.0);
      
}

}
        
        
        
        
        
        
        
        
        
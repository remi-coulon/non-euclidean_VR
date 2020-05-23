


//----------------------------------------------------------------------------------------------------------------------
// Texturing things
//----------------------------------------------------------------------------------------------------------------------


//--------Texturing Objects like the Tiling -------------------

// return the two smallest numbers in a triplet
vec2 smallest(in vec3 v)
{
    float mi = min(v.x, min(v.y, v.z));
    float ma = max(v.x, max(v.y, v.z));
    float me = v.x + v.y + v.z - mi - ma;
    return vec2(mi, me);
}

// texture a 4D surface by doing 4 2D projections in the most
// perpendicular possible directions, and then blend them
// together based on the surface normal
vec3 boxMapping(in sampler2D sam, in tangVector point)
{ // from Inigo Quilez
    vec4 m = point.dir*point.dir; m=m*m; m=m*m;

    vec3 x = texture(sam, smallest(point.pos.yzw)).xyz;
    vec3 y = texture(sam, smallest(point.pos.zwx)).xyz;
    vec3 z = texture(sam, smallest(point.pos.wxy)).xyz;
    vec3 w = texture(sam, smallest(point.pos.xyz)).xyz;

    return (x*m.x + y*m.y + z*m.z + w*m.w)/(m.x+m.y+m.z+m.w);
}



//--------Texturing the Earth -------------------

vec3 sphereOffset(Isometry globalObjectBoost, vec4 pt){
    pt = translate(cellBoost, pt);//move back to orig cell
    //changed this - it was done using a matrix not using translate
    pt = translate(getInverse(globalObjectBoost),  pt);//move back to origin
    //CHANGED TO XYW BECAUSE PRODUCT GEOMETRY
    return tangDirection(ORIGIN, pt).dir.xyw;//get the direction you are pointing from the origin.
    //this is a point on the unit sphere, and can be used to look up a  spherical  texture
}

vec3 earthColor(Isometry totalFixMatrix, tangVector sampletv){
        
    //this one stays xyz because it is about the texture not a point in space
        vec3 color = texture(earthCubeTex, sphereOffset(globalObjectBoost, sampletv.pos)).xyz;
 
    return color;
    }












//----------------------------------------------------------------------------------------------------------------------
// DECIDING BASE COLOR OF HIT OBJECTS, AND MATERIAL PROPERTIES
//----------------------------------------------------------------------------------------------------------------------

vec3  testColor;



//given the value of hitWhich, decide the initial color assigned to the surface you hit, before any lighting calculations
//in the future, this function will also contain more data, like its rerflectivity etc

vec3 materialColor(int hitWhich){
    
    if (hitWhich == 0){ //Didn't hit anything ------------------------
        testColor=vec3(1.,0.,0);
        //COLOR THE FRAME DARK GRAY
        //0.2 is medium gray, 0 is black
    return vec3(0.1);
    }
    else if (hitWhich == 1){//lightsource
        // in this case, either in the local or global scene sdf, when the threshhold was triggered, they automatically set colorOfLight correctly
        //so, we can just return that value here
        return colorOfLight;
    }
    else if (hitWhich == 2){//localObject
        //return vec3(0.,0.,0.);//black sphere
        return earthColor(totalFixMatrix,sampletv);
        //earth textured sphere
    }
    else if (hitWhich ==3) {//local object
    //first option; some fixed color preturbed by your position in the colo cube a bit.
        //.xyw here because of product factor
    return vec3(0.15,0.08,0.3)+(sampletv.pos.xyw+vec3(0.2,0.2,0.2))/8.;
    //return vec3(0.1,0.2,0.35);//just some random constant blue color
    }
    else if (hitWhich ==3) {//tiling
    return vec3(0.,0.,0.);//black sphere
    }
    
}


float materialReflectivity(int hitWhich){
    
    if (hitWhich == 0){ //Didn't hit anything ------------------------
        //COLOR THE FRAME DARK GRAY
        //0.2 is medium gray, 0 is black
    return 0.;
    }
    else if (hitWhich == 1){//lightsource (loc or  global)
        return 0.2;
    }
    else if (hitWhich == 2){//global Object
        //return 0.3;//black sphere
        return 0.;//earth, not reflective
    }
    else if (hitWhich ==3) {//tiling
    return mirror;//controlled by slider
    }
    else if (hitWhich ==4) {//local sphere object
    return 0.4;//shiny
    }
    
}













//----------------------------------------------------------------------------------------------------------------------
// CHOOSING ISOMETRY TO ADJUST LIGHTING, BASED ON LOCAL / GLOBAL NATURE OF OBJECTS
//----------------------------------------------------------------------------------------------------------------------





Isometry fixPositionTest(bool hitLocal){//look at values of hitLocal,
    
        if(hitLocal){//direct local light on local object
            testColor=vec3(1.,0.,0.);
            return identityIsometry;//GOOD
        }
        else{//direct local light on global object
           testColor=vec3(0.,1.,0.);
            return invCellBoost;//GOOD?
        }
    }
    


Isometry fixPositionTestGlobal(bool hitLocal){//look at values of hitLocal,
    
        if(hitLocal){//direct local light on local object
            testColor=vec3(1.,0.,0.);
            return composeIsometry(totalFixMatrix,invCellBoost);//GOOD
        }
        else{//direct local light on global object
           testColor=vec3(0.,1.,0.);
            return composeIsometry(totalFixMatrix,invCellBoost);//GOOD?
        }
    }
    



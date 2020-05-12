//----------------------------------------------------------------------------------------------------------------------
// Light Attenuation with  Distance
//----------------------------------------------------------------------------------------------------------------------
//light intensity as a fn of distance
float lightAtt(float dist){
    if (FAKE_LIGHT_FALLOFF){
        //fake falloff
        return 0.1+0.5*dist*dist*dist;
    }
    //actual distance function
    return 0.1+surfArea(dist);
}





//----------------------------------------------------------------------------------------------------------------------
// Getting  a Surface Normal
//----------------------------------------------------------------------------------------------------------------------

//NORMAL FUNCTIONS ++++++++++++++++++++++++++++++++++++++++++++++++++++
//Given a point in the scene where you stop raymarching as you have hit a surface, find the normal at that point
tangVector surfaceNormal(vec4 p) { 
    float newEp = EPSILON * 10.0;
    //basis for the tangent space at that point.
    mat4 theBasis= tangBasis(p);
    vec4 basis_x = theBasis[0];
    vec4 basis_y = theBasis[1];
    vec4 basis_z = theBasis[2];
    
    if (isLocal==0){ //global scene
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

//overload of the above to work being given a tangent vector
tangVector surfaceNormal(tangVector u){
    return surfaceNormal(u.pos);
}








//----------------------------------------------------------------------------------------------------------------------
// Specularity and Diffusivity of Surfaces
//----------------------------------------------------------------------------------------------------------------------
//SP - Sample Point | TLP - Translated Light Position | V - View Vector
vec3 phongShading(vec4 SP, vec4 TLP, tangVector viewVector, vec3 baseColor, vec4 lightColor, float lightIntensity){
    //Calculations - Phong Reflection Model
    
    //this is the direction from point on surface to the light source
    tangVector lightRay = tangDirection(SP, TLP);
    //this  is the reflection of this direction with respect to the surface normal
    tangVector reflectedRay = reflectOff(lightRay,N);
    //Calculate Diffuse Component
    float nDotL = max(cosAng(N, lightRay), 0.0);
    vec3 diffuse = lightColor.rgb * nDotL;
    //Calculate Specular Component
    float rDotV = max(cosAng(reflectedRay, viewVector), 0.0);
    vec3 specular = lightColor.rgb * pow(rDotV,20.0);
    //Attenuation - Of the Light Intensity
    float distToLight = fakeDistance(SP, TLP);
    float att = lightIntensity /lightAtt(distToLight);
    //Combine the above terms to compute the final color
    return (baseColor*(diffuse + .15) + vec3(.8, .6, .3)*specular*2.) * att;
   //return att*((diffuse*baseColor) + specular);
}



//----------------------------------------------------------------------------------------------------------------------
// Shadows
//----------------------------------------------------------------------------------------------------------------------

//only have the local light source which you are carrying around cast shadows.
//ro is where you are
//rd is the direction to the light source

float shadow( in vec4 ro, in vec4 rd, float mint, float maxt )
{
    for(float t=mint; t<maxt; )
    {
        float h = localSceneSDF(ro + rd*t);
        if( h<0.001 )
            return 0.0;
        t += h;
    }
    return 1.0;
}





// Cheap shadows are hard. In fact, I'd almost say, shadowing repeat objects - in a setting like this - with limited 
// iterations is impossible... However, I'd be very grateful if someone could prove me wrong. :)
float softShadow(vec4 ro, vec4 lp, float k){
//
    // More would be nicer. More is always nicer, but not really affordable... Not on my slow test machine, anyway.
    const int maxIterationsShad = 40; 
    
    //ray direction here
    vec4 rd = lp - ro; // Unnormalized direction ray.

    float shade = 1.;
    float dist = .002;    
    float end = max(length(rd), .01);
    float stepDist = end/float(maxIterationsShad);
    
    //normalizing the direction  ray
    rd /= end;

    // Max shadow iterations - More iterations make nicer shadows, but slow things down. Obviously, the lowest 
    // number to give a decent shadow is the best one to choose. 
    for (int i = 0; i<maxIterationsShad; i++){
        
        
//only going to have shadows cast by the tiling scene for now
        float h = localSceneSDF(ro + rd*dist);
        //shade = min(shade, k*h/dist);
        shade = min(shade, smoothstep(0., 1., k*h/dist)); // Subtle difference. Thanks to IQ for this tidbit.
        // So many options here, and none are perfect: dist += min(h, .2), dist += clamp(h, .01, .2), 
        // clamp(h, .02, stepDist*2.), etc.
        dist += clamp(h, .02, .25);
        
        // Early exits from accumulative distance function calls tend to be a good thing.
        if (h<0.01 || dist>end) break; 
        //if (h<.001 || dist > end) break; // If you're prepared to put up with more artifacts.
    }

    // I've added 0.5 to the final shade value, which lightens the shadow a bit. It's a preference thing. 
    // Really dark shadows look too brutal to me.
    return min(max(shade, 0.)+0.1, 1.); 
}










//----------------------------------------------------------------------------------------------------------------------
// Fog
//----------------------------------------------------------------------------------------------------------------------





























//----------------------------------------------------------------------------------------------------------------------
// DOING ALL THE LIGHTING  CALCULATIONS
//----------------------------------------------------------------------------------------------------------------------



vec3 lightingCalculations(Isometry totalFixMatrix, vec3 color){
    //sample point on the surfaxe
    vec4 SP = sampletv.pos;
    vec4 TLP;//translated light position
    //tangent vector at sample point pointing back at viewer
    tangVector V = turnAround(sampletv);

    //intrinsic color of the surface
    //vec3 surfColor=color;
    //set here to be the input color, whitened a bit
    vec3 surfColor=0.2*vec3(1.)+0.8*color;
    
    

    //--------------------------------------------------
    //Lighting Calculations
    //--------------------------------------------------

    
    float sh=1.;
    
    //GLOBAL LIGHTS
    //right now only drawing one light
    for (int i = 0; i<4; i++){
        //for each global light, translate its position via fixMatrix and cellBost
        Isometry totalIsom=composeIsometry(totalFixMatrix, invCellBoost);
        TLP = translate(totalIsom, lightPositions[i]+vec4(0.,0.,sin(time/2000.)/5.,0.));
        //run the lighting calculation for this  light position
        //also run the shadow computation for this light position!
        //add the resulting color to the original.
    //    sh=softShadow(SP,TLP,6.);
        
        //add this color to the pixel
        color += sh*phongShading(SP, TLP, V, surfColor, lightIntensities[i],2.);//the two here is the light intensity hard coded right now
        
        
    }

    
    //LOCAL LIGHT
    

        //+vec4(0.05,0.05,0.05,0.);
    sh=softShadow(SP,localLightPos,2.);
    color+= sh*phongShading(SP, localLightPos, V, surfColor, localLightColor,0.05+5.*brightness*brightness);
    
    
    //going to do shadows for the  local light:
    
    
    //light color and intensity hard coded in


   // move local light around by the generators to pick up lighting from nearby cells
   // this is not a good fix for local lighting - as there may be more than six neighbor cubes (ie near the vertices)
    for (int i=0; i<6; i++){
        TLP=invGenerators[i]*localLightPos;
        //local lights intensity is a function of its radius: so it gets brighter when it grows:
        color+= phongShading(SP, TLP, V, surfColor, localLightColor,0.05+5.*brightness*brightness);
    }
    
    
    
    //now that we've done the lighting calculation; can do the other things that might be usefu; like adding fog
    //this creates fog whose thickness depends on the distance marched (as a fraction of MAX_DIST)
    //the FACTOR OF 20 HERE IS JUST EXPERIMENTAL RIGHT NOW: looks like we are never reaching max dist before iteration time runs out in Euclidean geometry
    float fogF = smoothstep(0., MAX_DIST/10., distToViewer+0.2*distToViewer*distToViewer);
    //    // Applying the background fog. Just black, in this case, but you could
    // the vec3(0.1) is the backgroud dark gray that is drawn when we hit nothing: so making  the fog limit to this makes objects fade out
    color = mix(color, vec3(0.02,0.02,0.02), fogF); 

    return color;
}














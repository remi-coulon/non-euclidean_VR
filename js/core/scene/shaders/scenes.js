// language=Mustache + GLSL
export default `//
/***********************************************************************************************************************
 ***********************************************************************************************************************
 * 
 * Defines the scene SDF and scene Material computations used during the ray-marching and lightening.
 *
 ***********************************************************************************************************************
 **********************************************************************************************************************/

/**
 * Distance along the geodesic directed by \`v\` to the closest object in the local scene
 * @param[in] v the direction to follows
 * @param[out] hit say if we hit an object (1), nothing (0) or if there is a bug (-1)
 * @param[out] objId the ID of the solid we hit.
 */
float localSceneSDF(RelVector v, out int hit, out int objId){
    hit = HIT_NOTHING;
    float res = camera.maxDist;
    float dist;
    
    {{#_solids}}
        {{#isLocal}}
            dist = {{shape.name}}_sdf(v);
            if(abs(dist) < camera.threshold) {
            hit = HIT_SOLID;
            objId = {{id}};
            return dist;
            }
            res = min(res, dist);
        {{/isLocal}}
    {{/_solids}}
    
    return res;
}


/**
 * Distance along the geodesic directed by \`v\` to the closest object in the global scene
 * @param[in] v the direction to follows
 * @param[out] hit say if we hit an object (1), nothing (0) or if there is a bug (-1)
 * @param[out] objID the ID of the solid we hit.
 */
float globalSceneSDF(RelVector v, out int hit, out int objId){
    hit = HIT_NOTHING;
    float res = camera.maxDist;
    float dist;
    
    {{#_solids}}
        {{#isGlobal}}
            dist = {{shape.name}}_sdf(v);
            if(abs(dist) < camera.threshold) {
            hit = HIT_SOLID;
            objId = {{id}};
            return dist;
            }
            res = min(res, dist);
        {{/isGlobal}}
    {{/_solids}}
    
    return res;
}

/**
 * Color of the hit solid
 * @param[in] v the vector at which we hit the object
 * @param[in] objId the id of the object that we hit
 */
vec3 solidColor(RelVector v, int objId) {
    RelVector normal;

    switch(objId){
        {{#_solids}}
            case {{id}}:
                normal = {{shape.name}}_gradient(v);
                return {{material.name}}_render(v, normal);
        {{/_solids}}
    }
    
    // this line should never be achieved
    return vec3(0,0,0);
}
`;
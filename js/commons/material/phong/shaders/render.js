// language=Mustache + GLSL
export default `//
vec3 {{name}}_render(RelVector v, RelVector normal) {
    RelVector[1] dirs;
    float[1] intensities;
    int k;
 
    PhongMaterial material = {{name}};
    vec3 color = vec3(0);
 
    
    {{#lights}}
        k = {{name}}_directions(v, dirs, intensities);
        for(int j=0; j < k; j++){
        color = color + lightComputation(v.local, normal.local, dirs[j].local, material, {{name}}.color, intensities[j]);
        }
    {{/lights}}
    
    return color;
}
`;
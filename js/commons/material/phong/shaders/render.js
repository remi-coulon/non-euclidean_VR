// language=Mustache + GLSL
export default `//
vec3 {{name}}_render(RelVector v, RelVector normal) {
    bool check;
    RelVector dir;
    float intensity;
    int k;
 
    PhongMaterial material = {{name}};
    vec3 color = vec3(0);

    {{#lights}}
        k = {{name}}.maxDirs;
        for(int j=0; j < k; j++){
            check = {{name}}_directions(v, j, dir, intensity);
            if(check) {
                color = color + lightComputation(v.local, normal.local, dir.local, material, {{name}}.color, intensity);
            }
        }
    {{/lights}}
    
    return color;
}
`;
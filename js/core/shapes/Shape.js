import {Generic} from "../Generic.js";

/**
 * @class
 * @abstract
 *
 * @classdesc
 * A representation of a 3D geometric shape.
 * It should not be confused with Three.js `Shape` class.
 * It is more an analogue of the class `BufferGeometry` in Three.js.
 */
export class Shape extends Generic {

    /**
     * Constructor.
     * The constructor takes no argument.
     */
    constructor() {
        super();
    }

    /**
     * Says that the object inherits from `Shape`
     * @type {boolean}
     */
    get isShape() {
        return true;
    }

    /**
     * Says whether the shape is a basic shape,
     * that it is not build on top of other shapes.
     * @type {boolean}
     */
    get isBasicShape() {
        throw new Error('Shape: this method should be implemented');
    }

    /**
     * Return the chunk of GLSL code corresponding to the signed distance function.
     * @abstract
     * @return {string}
     */
    glslSDF() {
        throw new Error('Shape: this method should be implemented');
    }

    /**
     * Return the chunk of GLSL code corresponding to the gradient field.
     * @abstract
     * @return {string}
     */
    glslGradient() {
        throw new Error('Shape: this method should be implemented');
    }

    /**
     * Compile all the function directly related to the object (e.g. sdf, gradient, etc).
     * @return {string}
     */
    glslLogic() {
        return this.glslSDF() + "\r\n" + this.glslGradient();
    }
}


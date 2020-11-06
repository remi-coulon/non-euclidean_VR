/**
 * @module builder
 *
 * @description
 * Module defining the scene builder.
 * All the classes in the module are called SceneSomething, to avoid conflicts with reserved names (e.g. Object)
 */

import {
    Position
} from "../geometry/abstract.js";

/**
 *
 *
 * @class
 *
 * @classdesc
 * Object used to create a scene.
 *
 * @property {string} geometry - the underlying geometry
 * @property lattice - the lattice used for local scenes
 * @property {array} options - the general options of the scene
 * @property {array} items - the list of items in the scene (lights, objects, etc)
 *
 * @todo Decide the list of available options
 */
class SceneBuilder {

    /**
     * Create an instance dedicated to build a scene in the prescribed geometry.
     * @param {string} geometry - the underlying geometry
     * @param {array} options - a list of options
     */
    constructor (geometry, options = null){}

    /**
     * Setup the lattice used for the local scene.
     * @param data - some data describing the lattice
     * @return {SceneBuilder}
     *
     * @todo Decide how the lattice should be defined
     */
    setLattice(data){}

    /**
     * Set the given options.
     * @param {array} options - global options for the scene
     * @return {SceneBuilder}
     */
    setOptions(options){}

    /**
     * Set the given option.
     * @param {string} key - key of the option
     * @param {Object} value - the value of the option
     * @return {SceneBuilder}
     */
    setOption(key, value){}

    /**
     * Adding an item to the scene.
     * This method need be declined for every kind of objects available in the geometry.
     * The precise lists of items will vary depending on the geometry.
     * @return {SceneBuilder}
     */
    addItem(){}

    /**
     * Build the shader from templates files.
     * @return {string} - the code of the shader
     */
    async build(){}
}


/**
 * @class
 *
 * @classdesc
 * Material for objects in the scene
 *
 * @see Further information on the {@link https://en.wikipedia.org/wiki/Phong_reflection_model|Phong lighting model}
 *
 * @property {Vector4} color - color of the object
 * @property {number} specular - specular reflection constant
 * @property {number} diffuse - diffuse reflection constant
 * @property {number} ambient - ambient reflection constant
 * @property {number} shininess - shininess constant
 *
 * @todo Decide what to do for texture, color given by formulas, etc
 */

class SceneMaterial {

    /**
     * Constructor. Build a new material from the given data
     * @param {array} data - the properties of the material
     */
    constructor(data) {
    }
}

/**
 * @class
 *
 * @classdesc
 * Generic class for items in the scene (objects, lights, etc)
 * This class should never be instantiated directly.
 * Classes that inherit from SceneItem can be instantiated
 * All the properties are not mandatory.
 * Their use will depend on the type of objects.
 * The philosophy is to collect in this class all properties that can be used in more that one inherited class,
 * so that the code is factored as much as possible
 *
 * @property {number} id - a unique ID
 * @property {boolean} global  - flag: true if the item is in the global scene, false otherwise
 * @property {boolean} light - flag: true if the item is a light, false otherwise
 * @property {boolean} render - flag: true if the item should be rendered, false otherwise (useful for lights)
 * @property {SceneMaterial}  material - material of the item
 * @property {Vector3} lightColor - color of the light (if the item is a light)
 * @property {Position} position - location and facing of the object. The facing only matters for textures?
 * @property {function} positionCallback - a function that update the position (for animated objects)
 *
 */
class SceneItem {

    /**
     * Constructor.
     * @param {array} data
     * @todo Decide what arguments the generic constructor should receive
     */
    constructor(data) {
    }
}

export {
    SceneBuilder,
    SceneMaterial
}
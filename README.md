# Setup

* Get the [latest Geodot build for your platform](https://github.com/boku-ilen/geodot-plugin/actions) and copy the `addons/geodot` folder into this project
* Copy Setup/configuration.ini to configuration.ini in the `user://` path (`AppData` on Windows, `.local/share` on Linux) and adapt the GeoPackage path
    * On Linux, you can also use `Setup/setup_linux.sh` for this
* Open the Godot project 
* Run the main scene

We currently don't provide an executable runtime package.

## Credits

A build of our [Geodot plugin](https://github.com/boku-ilen/geodot-plugin) is included, along with the required GDAL library. All credits for GDAL go to [OSGeo/gdal](https://github.com/OSGeo/gdal/) ([license](https://raw.githubusercontent.com/OSGeo/gdal/master/gdal/LICENSE.TXT)).

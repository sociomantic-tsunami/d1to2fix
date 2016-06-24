========
d1to2fix
========

This is a simple tool based on `libdparse
<https://github.com/Hackerpilot/libdparse>`_ to automatically perform some
final conversion from D1 to D2.

Some of the conversions performed:

* Convert all delegates into scope delegates to reduce GC allocations from
  uncalled closures. For now aliased delegate types are not converted as it
  requires more complicated symbol processing. As a result, when an ``alias``
  to a ``delegate`` is used as function parameter, ``/* d1to2fix_inject: scope
  */`` should be used.

* Convert D1-style manifest constants (``const Name = Value;``) to ``enum`` in
  ``struct`` and ``static immutable`` everywhere else.

* Convert all ``this`` mentions inside struct bodies to pointers to match D1.

* Inject some D2 attributes based on special comments ``/* d1to2fix_inject: ...
  */`` (only ``const``, ``inout`` and ``scope`` supported for now).


Building
--------

To build just type ``make`` or use ``dub`` directly. To build a Debian package
type ``make deb`` (you need `fpm <https://github.com/jordansissel/fpm>`_ for
this to work though).


Docker
------

If you want to use Docker__ for testing without having to install all the
dependencies in your personal environment, you can easily do so, an image
definition is provided in the ``docker/`` directory.

__ https://www.docker.com/

To build you can use ``docker build -t d1to2fix docker`` and then to run::

  docker run -ti --rm -v $PWD:/d1to2fix -w /d1to2fix d1to2fix [<command>]

If you don't enter a ``<command>`` you'll get a shell inside the image to do
whatever you want. Otherwise you can just do a one run of, for example, ``dub
build`` inside Docker.

If you don't want to run stuff as root inside Docker, you can use a pre-defined
``docker`` user (UID 65456) with ``-u docker``, but you'll have to make sure
your files are accesible to that user.


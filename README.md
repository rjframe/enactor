# Enactor - Actor library for the D language

Important note (don't ignore this): Enactor is not in a usable state yet.

## Table of Contents

* [Introduction](#introduction)
    * [Current Design / Limitations](#current-design-and-limitations)
    * [License](#license)
* [Getting Started](#getting-started)
    * [Usage](#usage)
    * [Known Issues](#known-issues)
* [Running Tests](#running-the-tests)
* [Contributing](#contributing)
    * [Roadmap](#roadmap)
    * [Code of Conduct](#code-of-conduct)
    * [Acknowledgements](#acknowledgments)
* [Contact](#contact)
* [Related Projects](#related-projects)

## Introduction

Enactor will be a framework for building resilient applications in D via the
actor model.

Enactor seeks to enable:
- Fault-tolerance: supervisors will bring failed components back to their
  initial state when things go kablooey.
- Scalability: build small, easily understood components that communicate across
  the same process, different processes, or different machines as if it's all
  the same.

The [documentation for the Akka
library](https://doc.akka.io/docs/akka/current/guide/actors-intro.html) provides
a good introduction to actors.

Enactor will have two compatible actor APIs; a general-purpose API utilizing
classes as actors, and a high-performance API with lightweight actors for
applications that require creating and destroying thousands of actors regularly.

Structs are recognizable as actors but cannot be part of a supervisory tree.

Key Features:
- Class-based actor API that utilizes mixins rather than inheritance to avoid
  constraining you.
- (future) High performance actors.
- (future) Drop-in your custom scheduler.
- (future) Communication across processes/machines; deployment decisions are
  deploy-time decisions.


### Current Design and Limitations

- Actors must be classes (it's technically only required to place them in a
  supervisory tree).
- The receive method(s) cannot be templated.
- We currently only support limited multi-threading; see
  [Known Issues](#known-issues) below for more information.


## License

This project is licensed under the MIT license - see [LICENSE.md](LICENSE.md)
for details.


## Getting Started

Enactor is a framework, not just a library. Design decisions made by enactor
will determine what you can and cannot (readily) do in your application.

Note that enactor does add fields to your objects; names prefixed with `_act_`
are reserved for enactor's exclusive use, though if your serializer is unable to
de/serialize actors due to any such field, file a bug on enactor.


### Usage

Add to your dub.json:

```json
"dependencies": {
    "enactor": "~>0.0.1"
}
```

Or dub.sdl:
```
dependency "enactor" version="~>0.0.1"
```

At this time, the code example below is just a possibility; it has not yet been
implemented.

TODO: Create a useful example.
```d
import enactor : Supervisor, Actor;

struct MyMessage { int i; }

class Super {
    mixin Supervisor;
}

class Act {
    mixin Actor;

    int val;
    void receive(MyMessage m) {
        val = m.i;
    }
}

void main() {
    import enactor;

    auto root = new MainActor();
    auto super = root.supervise(new Super(), Supervise.RestartOnFail);
    auto one = super.supervise(new Act(), Supervise.RestartOnFail);
    auto two = super.supervise(new Act(), Supervise.RestartOnFail);

    one.send(two, MyMessage(1));
    assert(two.val == 1);

    register("my-address", one);
    send("my-address", MyMessage(2));
    assert(one.val == 2);
}
```


### Known Issues

#### Multi-threading

Currently, MainActor will spawn a supervisor for each processor core - 1.
Actors will be registered to each supervisor equally, under the assumption that
each actor will on average do the same work, which is often not going to be the
case. Moving an actor from one core to another is not yet supported, but they
can communicate across cores just as they do other actors on the same core.

In time I'll do proper multi-threading; I'm waiting to see how the current
memory-management tools in D are going to change before jumping in on this.


## Running the Tests

Running tests requires unit-threaded (automatically installed by dub):

```shell
$ dub test
```


## Contributing

Pull requests are welcome. For major features or breaking changes, please open
an issue first so we can discuss what you would like to do.

And don't forget the tests!


### Roadmap

My current plans/designs for:

#### High-performance Actors

At its core, all we need for an "actor" is a delegate with private state
and a mailbox. We should be able to do this more cheaply than constructing and
destroying classes. We should be able to provide something lightweight enough
that we can efficiently create thousands of actors on demand.

#### Inter-process/machine Communication

The actor registry should be distributed; component deployment and configuration
is a sysadmin's domain, and shouldn't be forced by application design decisions.

#### Error Handling / Debugging Tools

The call stack becomes rather useless with the actor model, so we need to
provide help with debugging (errors as messages, etc.).


## Contact

- Website: <[www.ryanjframe.com](https://www.ryanjframe.com)>
- Email: <code@ryanjframe.com>
- diaspora*: rjframe@resocial.strangelyinbetween.com

## Related Projects

Libraries for D:

* Phobos: If all you need is message passing between threads, there's
  [std.concurrency](https://dlang.org/phobos/std_concurrency.html).
- [Dakka](http://code.dlang.org/packages/dakka)

Libraries for other languages:

- [Akka](https://akka.io) (for Java, Scala or [.NET](https://getakka.net))
- [C++ Actor Framework](https://actor-framework.org)
- [Riker](https://riker.rs) (for Rust)

Actor languages:

- [Erlang](https://www.erlang.org)/[Elixer](https://elixir-lang.org) (CSP)
- [Io](http://iolanguage.org)
- [Pony](https://www.ponylang.io)

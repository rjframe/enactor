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
applications that require regularly creating and destroying many actors.

Key Features:
- Class-based actor API that utilizes mixins rather than inheritance to avoid
  constraining you.
- (future) High performance actors.
- (future) Drop-in your custom scheduler.
- (future) Communication across processes/machines; deployment decisions are
  deploy-time decisions.


### Current Design and Limitations

- Actors must be classes.
- The receive method(s) cannot be templated.
- Multi-threading isn't supported or tested yet; see
  [Known Issues](#known-issues) below for more information.


## License

This project is licensed under the MIT license - see [LICENSE.md](LICENSE.md)
for details.


## Getting Started

Enactor is a framework, not just a library. Design decisions made by enactor
will determine what you can and cannot (readily) do in your application.

Enactor does add fields to your objects; names prefixed with `_act_`
are reserved for enactor's exclusive use and should be ignored in your
de/serializers and other introspective tasks. If enactor's methods or fields
break your generic/introspective code, file a bug on enactor.

### Usage

Enactor is not yet registered on dub. You'll need to clone the repository and
add it as a path-based dependency to your project.

(future) Add the dependency via dub: `dub add enactor`


#### Slow fibonacci example:

```d
import enactor;

class Adder {
    mixin Actor;

    this(string otherName) {
        this.other = otherName;
    }

    void receive(int j) {
        i += j;
        send(other, i);
        if (i > 10) send("main", Application.ExitSuccess);
    }

    private:

    int i = 0;
    string other;
}

void main() {
    import enactor;

    auto m = new MainActor();

    auto first = new Adder("adderTwo");
    auto second = new Adder("adderOne");
    register("adderOne", first);
    register("adderTwo", second);

    send("a", 1);
    m.start();

    writeln("Last two numbers: ", first.i, " and ", second.i);
}
```


### Known Issues

#### Multi-threading

Enactor currently runs all actors in a single thread.

The initial plan will be: MainActor will spawn a supervisor for each processor
core - 1. Actors will be registered to each supervisor equally, under the
assumption that each actor will on average do the same work (which is not
necessarily true). Moving an actor from one core to another is not yet
supported, but they can communicate across cores just as they do other actors on
the same core.

In time I'll do proper multi-threading and you'll be able to swap schedulers
with custom implementations; I'm waiting to see how the current memory-management
tools in D are going to change before jumping in on this. I'm  beginning small,
ensuring I have something, and will test and improve/replace as we go along.


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

Supporting a distributed actor registry means you can easily separate your
components onto new processes and machines, allowing you scale as necessary
based on production data; you don't have to guess your architecture needs during
development.


#### Error Handling / Debugging Tools

The call stack becomes rather useless with the actor model, so we need to
provide help with debugging (errors as messages, etc.).


## Contact

- Website: <[www.ryanjframe.com](https://www.ryanjframe.com)>
- Email: <code@ryanjframe.com>
- diaspora*: <rjframe@diasp.org>

## Related Projects

Libraries for D:

- Phobos: If all you need is message-passing between threads, there's
  [std.concurrency](https://dlang.org/phobos/std_concurrency.html).
- [Dakka](http://code.dlang.org/packages/dakka) (last update was 2015)

Libraries for other languages:

- [Akka](https://akka.io) (for Java, Scala or [.NET](https://getakka.net))
- [C++ Actor Framework](https://actor-framework.org)
- [Riker](https://riker.rs) (for Rust)

Actor languages:

- [Erlang](https://www.erlang.org)/[Elixer](https://elixir-lang.org) (CSP)
- [Io](http://iolanguage.org)
- [Pony](https://www.ponylang.io)

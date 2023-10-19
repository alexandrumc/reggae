module tests.it.runtime.issues;


import tests.it.runtime;


// reggae/dub build should rebuild if dub.json/sdl change
@("23")
@Tags(["dub", "make"])
unittest {

    import std.process: execute;
    import reggae.path: buildPath;

    with(immutable ReggaeSandbox("dub")) {
        runReggae("-b", "make", "--dflags=-g");
        make(["VERBOSE=1"]).shouldExecuteOk.shouldContain("-g");
        {
            const ret = execute(["touch", buildPath(testPath, "dub.json")]);
            ret.status.shouldEqual(0);
        }
        {
            const ret = execute(["make", "-C", testPath]);
            // don't assert on the status of ret - it requires rerunning reggae
            // and that can fail if the reggae binary isn't built yet.
            // Either way make should run
            ret.output.shouldNotContain("Nothing to be done");
        }
    }
}


@("62")
@Flaky
@Tags(["dub", "make"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "issue62"
            dependency "arsd-official:nanovega" version="*"
        `);
        writeFile("source/app.d", q{
                import arsd.simpledisplay;
                import arsd.nanovega;
                void main () { }
            }
        );
        runReggae("-b", "make");
        make.shouldExecuteOk;
        shouldSucceed("issue62");
    }
}


@("73")
@Tags("issues", "ninja")
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("include/lib.h", `int twice(int i);`);
        writeFile("src/lib.c", `
            #include "lib.h"
            int twice(int i) { return i * 2; }
        `);
        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias mylib = staticLibrary!(
                          "mylib",
                          Sources!("src"),
                          Flags(),
                          ImportPaths(["include"]),
                      );
                      mixin build!mylib;
                  }
        );
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
    }
}



@("dubLink")
@Tags(["dub", "make"])
unittest {
    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl", `
            name "dublink"
        `);
        writeFile("source/app.d", q{
                void main () { }
            }
        );
        writeFile("reggaefile.d",
                  q{
                      import reggae;
                      alias sourceObjs = dlangObjects!(Sources!"source");
                      alias exe = dubLink!(TargetName("exe"), Configuration("default"), sourceObjs);
                      mixin build!exe;
                  });
        runReggae("-b", "make");
        make.shouldExecuteOk;
        shouldSucceed("exe");
    }
}


@("127.0")
@Tags("dub", "issues", "ninja")
unittest {

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl",
            [
                `name "issue157"`,
                `targetType "executable"`,
                `targetPath "daspath"`
            ]
        );

        writeFile("source/app.d",
            [
                `void main() {}`,
            ]
        );

        version(Windows) {
            enum ut = `daspath\issue157-test-application.exe`;
            enum bin = `daspath\issue157.exe`;
        } else {
            enum ut = "daspath/issue157-test-application";
            enum bin = "daspath/issue157";
        }

        runReggae("-b", "ninja");
        ninja(["default", ut]).shouldExecuteOk;

        shouldExist(bin);
        shouldExist(ut);
    }
}


@("127.1")
@Tags("dub", "issues", "ninja")
unittest {

    import std.file: mkdir;

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl",
            [
                `name "issue157"`,
                `targetType "executable"`,
                `targetPath "daspath"`
            ]
        );

        writeFile("source/app.d",
            [
                `void main() {}`,
            ]
        );

        const bin = inSandboxPath("bin");
        mkdir(bin);
        runReggae("-C", bin, "-b", "ninja", testPath);
        ninja(["-C", bin, "default", "ut"]).shouldExecuteOk;

        version(Windows) {
            shouldExist(`bin\issue157.exe`);
            shouldExist(`bin\issue157-test-application.exe`);
        } else {
            shouldExist("bin/issue157");
            shouldExist("bin/issue157-test-application");
        }
    }
}


@("140")
@Tags("dub", "issues", "ninja")
unittest {

    import std.path: buildPath;

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl",
            [
                `name "issue140"`,
                `targetType "executable"`,
                `targetPath "daspath"`,
                `dependency "bar" path="bar"`
            ]
        );

        writeFile("source/app.d",
            [
                `void main() {}`,
            ]
        );

        writeFile(
            "bar/dub.sdl",
            [
                `name "bar"`,
                `copyFiles "$PACKAGE_DIR/txts/text.txt"`
            ]
        );
        writeFile("bar/source/bar.d",
            [
                `module bar;`,
                `int twice(int i) { return i * 2; }`,
            ]
        );

        writeFile("bar/txts/text.txt", "das text");

        runReggae("-b", "ninja");
        ninja(["default"]).shouldExecuteOk;
        shouldExist(buildPath("daspath", "text.txt"));
    }
}


@("144")
@Tags("dub", "issues", "ninja")
unittest {

    import std.path: buildPath;

    with(immutable ReggaeSandbox()) {
        writeFile("dub.sdl",
            [
                `name "issue144"`,
                `targetType "executable"`,
                `configuration "default" {`,
                `}`,
                `configuration "daslib" {`,
                `    targetType "library"`,
                `    excludedSourceFiles "source/main.d"`,
                `}`,
                `configuration "weird" {`,
                `    targetName "weird"`,
                `    versions "weird"`,
                `}`,
            ]
        );

        writeFile("source/main.d",
            [
                `void main() {}`,
            ]
        );

        writeFile("source/lib.d",
            [
                `int twice(int i) { return i * 2; }`,
            ]
        );

        version(Windows) {
            enum exe = "issue144.exe";
            enum lib = "issue144.lib";
        } else {
            enum exe = "issue144";
            enum lib = "issue144.a";
        }

        runReggae("-b", "ninja", "--dub-config=daslib");

        ninja([lib]).shouldExecuteOk;
        ninja([exe]).shouldFailToExecute.should ==
            ["ninja: error: unknown target '" ~ exe ~ "', did you mean '" ~ lib ~ "'?"];
        // No unittest target when --dub-config is used
        ninja(["ut"]).shouldFailToExecute.should ==
            ["ninja: error: unknown target 'ut'"];
    }
}

@Tags("issues", "ninja")
@("193")
unittest {
    with (immutable ReggaeSandbox()) {
        writeFile(
            "reggaefile.d",
            q{
                import reggae;
                alias testObjs = objectFiles!(
                    Sources!(["src"], Files(["test.d"])),
                    Flags("-g"),
                    ImportPaths(["src"]),
                );
                alias app = link!(ExeName("app"), testObjs);
                mixin build!app;
            }
        );
        writeFile(
            "test.d",
            q{
                static import foo;
                int main() {
                    return foo.foo(42);
                }
            }
        );
        writeFile(
            "src/foo.d",
            q{
                module foo;
                int foo(int i) { return i * 2; }
            }
        );
        runReggae("-b", "ninja");
        ninja.shouldExecuteOk;
    }
}

// on Windows the exception message is slightly different and it's just not worth it
version(Posix) {
    @Tags("issues", "ninja")
    @("194")
    unittest {
        with (immutable ReggaeSandbox()) {
            writeFile("reggaefile.d",
                      [
                          `import reggae;`,
                          `enum foo = Target("foo/bar/quux", "make -C DIR bin/exe DMD=sdc");`,
                          `mixin build!foo;`,
                      ]
            );
            runReggae("-b", "ninja").shouldThrowWithMessage(
                "Couldn't execute the produced buildgen binary:\n" ~
                "Cannot have a custom rule with no $in or $out: " ~
                "use `phony` or explicit $in/$out instead.\n");
        }
    }
}

@("210")
@Tags("issues", "ninja")
unittest {
    with (immutable ReggaeSandbox()) {
        // we write to something containing "core" since the directory
        // name must include that to reproduce the bug
        writeFile(
            "no123core/dub.sdl",
            [
                `name "oops"`,
                `targetType "library"`,
            ]
        );
        // the reggaefile must exist since the bug had to do with
        // getting dependencies for it
        writeFile(
            "no123core/reggaefile.d",
            [
                `import reggae;`,
                `mixin build!(dubDefaultTarget!());`
            ]
        );
        writeFile("no123core/src/no123core/oops.d", "module no123core.oops;");
        runReggae("-b", "ninja", inSandboxPath("no123core"));
    }
}

@("dubConfig.implicit.default")
@Tags("dub", "issues", "ninja")
unittest {
    with (immutable ReggaeSandbox()) {
        // no *explicit* default configuration, should still work
        writeFile("dub.sdl", `name "oops"`);
        writeFile("source/oops.d", "void oops() {}");
        runReggae("-b", "ninja", "--dub-config=default");
    }
}

@("dubConfig.explicit.wrong")
@Tags("dub", "issues", "ninja")
unittest {
    with (immutable ReggaeSandbox()) {
        // no *explicit* default configuration, should still work
        writeFile("dub.sdl", `name "oops"`);
        writeFile("source/oops.d", "void oops() {}");
        runReggae("-b", "ninja", "--dub-config=ohnoes")
            .shouldThrowWithMessage(
                "Unknown dub configuration `ohnoes` - known configurations:\n    [\"library\"]");
    }
}

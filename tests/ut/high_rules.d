module tests.ut.high_rules;


import reggae;
import reggae.options;
import reggae.path: buildPath;
import unit_threaded;


version(Windows) {
    version(DigitalMars)
        immutable defaultDCModel = " -m32mscoff";
    else
        immutable defaultDCModel = "";
} else
    enum defaultDCModel = null;

@("C object file") unittest {
    immutable fileName = "foo.c";
    enum objPath = "foo" ~ objExt;
    auto obj = objectFile(Options(), SourceFile(fileName),
                           Flags("-g -O0"),
                           IncludePaths(["myhdrs", "otherhdrs"]));
    auto cmd = Command(CommandType.compile,
                        assocListT("includes", [buildPath("-I$project/myhdrs"), buildPath("-I$project/otherhdrs")],
                                   "flags", ["-g", "-O0"],
                                   "DEPFILE", [objPath ~ ".dep"]));

    obj.shouldEqual(Target(objPath, cmd, [Target(fileName)]));

    auto options = Options();
    options.cCompiler = "weirdcc";
    options.projectPath = "/project";
    version(Windows) {
        enum expected = `weirdcc /nologo -g -O0 -I\project\myhdrs -I\project\otherhdrs /showIncludes ` ~
                        `/Fofoo.obj -c \project\foo.c`;
    } else {
        enum expected = "weirdcc -g -O0 -I/project/myhdrs -I/project/otherhdrs -MMD -MT foo.o -MF foo.o.dep " ~
                        "-o foo.o -c /project/foo.c";
    }
    obj.shellCommand(options).shouldEqual(expected);
}

@("C++ object file") unittest {
    foreach(ext; ["cpp", "CPP", "cc", "cxx", "C", "c++"]) {
        immutable fileName = "foo." ~ ext;
        enum objPath = "foo" ~ objExt;
        auto obj = objectFile(Options(), SourceFile(fileName),
                               Flags("-g -O0"),
                               IncludePaths(["myhdrs", "otherhdrs"]));
        auto cmd = Command(CommandType.compile,
                            assocListT("includes", [buildPath("-I$project/myhdrs"), buildPath("-I$project/otherhdrs")],
                                       "flags", ["-g", "-O0"],
                                       "DEPFILE", [objPath ~ ".dep"]));

        obj.shouldEqual(Target(objPath, cmd, [Target(fileName)]));
    }
}


@("D object file") unittest {
    auto obj = objectFile(Options(), SourceFile("foo.d"),
                           Flags("-g -debug"),
                           ImportPaths(["myhdrs", "otherhdrs"]),
                           StringImportPaths(["strings", "otherstrings"]));
    enum objPath = "foo" ~ objExt;
    auto cmd = Command(CommandType.compile,
                        assocListT("includes", [buildPath("-I$project/myhdrs"), buildPath("-I$project/otherhdrs")],
                                   "flags", ["-g", "-debug"],
                                   "stringImports", [buildPath("-J$project/strings"), buildPath("-J$project/otherstrings")],
                                   "DEPFILE", [objPath ~ ".dep"]));

    obj.shouldEqual(Target(objPath, cmd, [Target("foo.d")]));
}

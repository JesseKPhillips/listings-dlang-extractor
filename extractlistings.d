/**
 * This program will extract programs from lstlisting in tex files.
 *
 * This program is built specifically to compile D programs in lstlisting for
 * the book "Learning with D."
 *
 * The goal is to include the results of a compile and run into the tex file.
 */
import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.process;
import std.range;
import std.regex;
import std.stdio;
import std.string;

int exampleCount;

void main(string[] args) {
    //enforce(args.length == 2 || args.length == 3,
    //        "Usage: " ~ args[0] ~ " file [example number]");
    int compileOnly;
    if(args.length == 2)
        compileOnly = to!int(args[1]);

    string file;
    foreach(line; stdin.byChunk(4096))
        file ~= line;
    while(true) {
        auto arr = file.findSplit(r"\begin{lstlisting}");
        write(arr[0]);
        file = arr[2];

        if(file.empty)
            break;
        string[] proglist;

        arr = file.findSplit(r"\end{lstlisting}");
        outputProgram(arr[0]);
        arr[0].findSkip("]");
        proglist ~= writeProgram(arr[0].strip);

        file = arr[2].strip;
        auto progtxt = arr[0];
        while(file.startsWith(r"\begin{lstlisting}")) {
            file.skipOver(r"\begin{lstlisting}");
            arr = file.findSplit(r"\end{lstlisting}");
            outputProgram(arr[0]);
            arr[0].findSkip("]");
            proglist ~= writeProgram(arr[0].strip);
            progtxt ~= arr[0];
            file = arr[2].strip;
        }

        if(compileOnly)
            if(compileOnly != exampleCount)
                continue;

        foreach(i; importFiles(progtxt))
            if(proglist.find(i).empty)
                proglist ~= i;

        executeExample(proglist, progtxt);

        writeln(readText(format("example%s.compile", exampleCount)));
    }
}

auto executeExample(string[] proglist, string progtxt) {
        auto f = File(format("example%s.compile", exampleCount), "w");
        scope(exit) f.close();
        f.writeln(r"\begin{verbatim}");
        scope(exit) f.writeln(r"\end{verbatim}");
        auto options = compileOptions(progtxt);
        auto inputs = inputsForFile(progtxt);
        auto infoFlags = flagsForFile(progtxt);
        if(compile(proglist, options, f))
            runProgram(proglist, inputs, f);
        else
            if(!(infoFlags & FileInfo.fails))
                stderr.writeln("Compile Failed: ", compileCommand(proglist, options));
}

enum FileInfo { none, fails = 1 }

auto flagsForFile(R)(R progtxt) {
    if(!match(progtxt, regex("// Fails:")).empty)
        return FileInfo.fails;
    return FileInfo.none;
}

auto compileOptions(R)(R progtxt) {
    string cmd;
    if(!match(progtxt, regex("unittest")).empty)
        cmd ~= "-unittest ";
    return cmd;
}

auto compileCommand(string[] proglist, string options) {
    string cmd = "dmd " ~ options;
    string compilerOutput = "compiler.out";

    return cmd ~ proglist.join(" ");
}

auto compile(string[] proglist, string options, File f) {
    string compilerOutput = "compiler.out";

    auto make = compileCommand(proglist, options);
    debug writeln(make);
    f.writeln("$ " ~ make);
    auto ret = executeShell(make ~ " > " ~ compilerOutput ~ " 2>&1");
    auto compilerText = readText(compilerOutput);
    scope(exit) remove(compilerOutput);

    debug if(compilerText) writeln(compilerText);
    if(!compilerText.empty)
        breakLines(compilerText, f);
    // No need to continue if compilation failed
    if(ret.status != 0) {
        debug {
            writeln("Compile Failed");
            writeln(make ~ " > " ~ compilerOutput ~ " 2>&1");
            writeln();
        }
        return false;
    }

    return true;
}

enum inputReg = ctRegex!("<input>");
auto runProgram(string[] proglist, string[] inputs, File f) {
    string programOutput = "program.out";
    string inputFile = "program.in";
    auto run = "./" ~ stripExtension(proglist.front);
    if(!inputs.empty) {
        auto inFile = File(inputFile, "w");
        scope(exit) if(exists(inputFile)) remove(inputFile);
        foreach(input; inputs) {
            inFile.writeln(input);
        }
        inFile.close();
        debug writeln(
               format(run ~ "< %s 2>&1 | tee %s", inputFile, programOutput));
        executeShell(format(run ~ "< %s > %s 2>&1", inputFile, programOutput));
    } else {
        debug writeln(run ~ " 2>&1 | tee " ~ programOutput);
        executeShell(run ~ " > " ~ programOutput ~ " 2>&1");
    }
    scope(exit) remove(programOutput);
    auto outText = readText(programOutput);

    foreach(input; inputs) {
        outText = outText.replace(inputReg, input ~ "\n");
    }

    debug if(progText) writeln(outText);
    f.writeln("$ " ~ run);
    if(!outText.empty)
        breakLines(outText.strip(), f);
}

auto writeProgram(R)(R prog) {
    auto name = programName(prog);

    auto f = File(name, "w");
    scope(exit) f.close();
    f.writeln(prog);

    return name;
}

auto breakLines(string text, File f) {
    auto txt = to!(dstring)(text);
    while(!txt.empty) {
        if(txt.length <= 55) {
            if(txt.back == '\n')
                f.write(txt);
            else
                f.writeln(txt);
            break;
        }

        auto lineLength = txt.countUntil("\n");
        if(lineLength != -1 && lineLength <= 55) {
            f.writeln(txt[0..lineLength]);
            txt = txt[lineLength+1..$];
            continue;
        }

        auto fade = txt[46..56].retro.countUntil(" ");
        if(fade == -1) {
            f.writeln(txt[0..56]);
            txt = txt[56..$];
            continue;
        }

        assert(txt[56-fade-1] == ' ');
        f.writeln(txt[0..56-fade-1]);
        txt = txt[56-fade..$];
    }
}

auto programName(R)(R prog) {
    exampleCount++;
    auto name = format("example%s.d", exampleCount);
    auto m = match(prog, regex("module (.+);"));
    if(!m.empty) {
        name = format("example_%s.d", m.captures[1]);
    }

    return name;
}

unittest {
    scope(success) exampleCount = 0;
    exampleCount = 0;
    assert("example1.d" == programName(q{
    import std.stdio;
    writeln("Hello");
    }.strip()));

    assert("example2.d" == programName(q{
    import std.stdio;
    writeln("Hello");
    }.strip()));

    assert("example_hello.d" == programName(q{
    module hello;
    import std.stdio;
    writeln("Hello");
    }.strip()));
}

auto importFiles(R)(R prog) {
    string[] proglist;
    foreach(line; prog.splitLines()) {
        line = line.strip();
        if(skipOver(line, "import ")) {
            line.replace(r"\.", "/");
            line = to!string(array(line.until(" ")));
            line = to!string(array(line.until(":")));
            line = to!string(array(line.until(";")));
            if(exists("example_"~line~".d"))
                proglist ~= "example_"~line~".d";
        } else {
            // Probably can ignore for sake of std.
            //TODO: Can't find file
        }
    }

    return proglist;
}

unittest {
    assert([] == importFiles(q{
    module hello;
    import std.stdio;
    }.strip()));

    executeShell("touch example_triangle.d");
    scope(exit) std.file.remove("example_triangle.d");
    assert(["example_triangle.d"] == importFiles(q{
    module hello;
    import triangle;
    import std.stdio;
    }.strip()));
}

auto inputsForFile(R)(R prog) {
    string[] inputs;
    foreach(line; prog.splitLines()) {
        line = line.strip();
        if(skipOver(line, "// Input: ")) {
            inputs ~= line;
        }
    }

    return inputs;
}

unittest {
    assert(["Jesse", "24"] == inputsForFile(q{
    module hello;
    import std.stdio;
    // Input: Jesse
    // Input: 24
    }.strip()));
}

/**
 * Output program text for lex file.
 *
 * Skips commands.
 */
auto outputProgram(R)(R progtxt) {
    write(r"\begin{lstlisting}");
    foreach(line; progtxt.splitLines()) {
        if(match(line.strip(), "// Input: "))
            continue;
        if(match(line.strip(), "// Fails:"))
            continue;
        line = line.replace(inputReg, "");
        writeln(line);
    }
    writeln(r"\end{lstlisting}");
    writeln();
}

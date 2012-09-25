listings-dlang-extractor
========================

This program will extract programs from lstlisting in tex files.

This program is built specifically to compile D programs in lstlisting for
the book "Learning with D." There is no intention to generalize or make customizable.

The goal is to include the results of a compile and run into the tex file.

Usage
-----

Reads lex file from standard in, writes to standard out.

Latex Listings
--------------

Insert code between the standard \begin{lstlisting} and \end{lstlisting} tags. Simple as that... with these complications.

Captions can be added, but must be on the same line as the begin. Other options can be included, but remain on the same line unless you wish to fix the code.

    \begin{lstlisting}[caption={Standard Input}]

Input can be entered, but there will be no output to explain what is being requested. Instead add Input: comments to your code to allow automation of inputing commands. Any string which requests input should use the &lt;input&gt; so that program run is correctly reflected in the output latex file.

    // Input: Jesse
    write("Please enter your name: <input>");

There is no intention to support any graphical programs, I may provide a signal to ignore a listing.

Multiple Files
--------------

Support for multiple files does exist. Just place multiple listings together without any explanation text between them. To import an example the example must be named. Provide a module declaration will allow importing via that name. As files are never removed, these named modules can be imported in subsequent examples, or even overwritten.

Unit Testing
------------

D provides in built unittest blocks. These are only run when passed the -unittest argument to the compiler. Simply add unittest blocks to your code, the compiler will be told to compile them in.

Program Arguments
-----------------

Command line arguments are not supported at this time, but I'll likely need them in the future.

Compiler Arguments
------------------

There is no option to pass arguments to the compiler. This will likely need changed in the future.

I will also likely need a way to specify multiple compile/runs against the same examples. This would help explain version/debug blocks.

Currently unittest is the only supported option and is automatically detected.

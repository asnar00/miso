# codegen
*generates executable implementations from pseudocode*

The `codegen` sub-feature transforms pseudocode instructions into working code in specific programming languages, creating the final executable tools.

It reads the generated pseudocode for each tool and produces language-specific implementations in the `run/[tool]/[language]/` directory structure. The code generator handles:

- **Language selection** based on tool requirements and project conventions
- **Template application** using patterns for argument parsing, main logic, and error handling  
- **Specific implementations** for known tools (like `hello`) vs generic templates for new tools
- **Executable setup** including proper file permissions and shebang lines

The generator creates fully functional programs that implement the specified behavior. For well-defined tools, it produces complete implementations. For vague or complex specifications, it generates TODO-marked templates that prompt for human completion.

Each generated file follows established conventions and includes documentation linking back to the original specification, maintaining traceability from natural language intent to executable code.
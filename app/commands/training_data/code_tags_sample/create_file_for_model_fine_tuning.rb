class TrainingData::CodeTagsSample::CreateFileForModelFineTuning
  include Mandate

  def call
    open_file!
    write_messages_for_tags!
    write_messages_for_samples!
    file.path
  ensure
    close_file!
  end

  private
  attr_reader :file

  def open_file!
    @file = Tempfile.new(['fine-tune-model', '.jsonl'])
  end

  def write_messages_for_tags!
    write_message!(
      "What are EXERCISM_REPRESENTATION_TAGS?",
      "EXERCISM_REPRESENTATION_TAGS are a standardised set of programming concepts, paradigms and techniques used to tag code. They are always lowercase and snake-case. There are two parts to a tag, split by a colon. The first part is one of four categories (construct, technique, paradigm and uses) and the second part is a specific tag within that category." # rubocop:disable Layout/LineLength
    )

    %w[construct paradigm technique].each do |namespace|
      write_message!(
        "Return the EXERCISM_REPRESENTATION_TAGS that are in the #{namespace} category as a JSON aray under a top level key of tags.",
        { tags: tags_with_namespace(namespace) }.to_json
      )
    end

    CRITERIA.each do |tag, criteria|
      write_message!(
        "When should a solution be tagged with the `#{tag}` EXERCISM_REPRESENTATION_TAG?",
        "It should be assigned when the code #{criteria}."
      )

      write_message!(
        "Which EXERCISM_REPRESENTATION_TAG should be tagged when the code #{criteria}?",
        "`#{tag}`"
      )
    end
  end

  def write_messages_for_samples!
    samples.each do |sample|
      next if sample.code.blank?
      next if sample.tags.blank?

      write_messages_for_sample_tags!(sample)
      write_messages_for_incorrect_llm_tags!(sample) if sample.llm_tags.present?
      write_messages_for_missing_llm_tags!(sample) if sample.llm_tags.present?
    rescue StandardError => e
      Bugsnag.notify(e)
    end
  end

  def samples
    TrainingData::CodeTagsSample.includes(:track).
      where(status: %i[community_checked admin_checked]).
      where.not(tags: nil)
  end

  def write_messages_for_sample_tags!(sample)
    instruction_text = <<~INSTRUCTION
      Respond with a JSON object containing one top-level key called tags containing an array of EXERCISM_REPRESENTATION_TAGS (programming concepts, paradigms and techniques) for this #{sample.track.title} code.

      ---

      #{sample.code}"
    INSTRUCTION

    write_message!(
      instruction_text.delete("\r"),
      sample.tags.to_json
    )
  end

  def write_messages_for_incorrect_llm_tags!(sample)
    incorrect_llm_tags = sample.llm_tags - sample.tags
    incorrect_llm_tags.each do |tag|
      criteria = CRITERIA[tag]
      next if criteria.blank?

      criteria = criteria.split
      criteria[0] = criteria[0].singularize
      criteria = criteria.join(' ')

      write_message!(
        "Given the following code, should it be assigned the `#{tag}` EXERCISM_REPRESENTATION_TAG, and why?\n#{sample.code}",
        "No, because it does not #{criteria}."
      )
    end
  end

  def write_messages_for_missing_llm_tags!(sample)
    missing_llm_tags = sample.tags - sample.llm_tags
    missing_llm_tags.each do |tag|
      criteria = CRITERIA[tag]
      next if criteria.blank?

      write_message!(
        "Given the following code, should it be assigned the `#{tag}` EXERCISM_REPRESENTATION_TAG, and why?\n#{sample.code}",
        "Yes, because it #{criteria}."
      )
    end
  end

  def write_message!(user, assistant)
    message = {
      messages: [
        { role: "system", "content": SYSTEM_TEXT },
        { role: "user", "content": user },
        { role: "assistant", "content": assistant }
      ]
    }

    file.write(message.to_json)
    file.write("\n")
  end

  def close_file!
    file.close
  end

  def tags_with_namespace(namespace)
    CRITERIA.keys.select { |tag| tag.starts_with?("#{namespace}:") }
  end

  SYSTEM_TEXT = 'You are a expert in EXERCISM_REPRESENTATION_TAGS'.freeze

  CRITERIA = {
    'construct:abstract-class' => 'defines an abstract class',
    'construct:abstract-method' => 'defines an abstract method',
    'construct:add-assignment' => 'combines addition with assignment',
    'construct:add' => 'uses addition',
    'construct:array' => 'uses or declares an array',
    'construct:assignment' => 'assigns or binds a value to a variable/name',
    'construct:async-await' => 'uses `async`/`await`',
    'construct:attribute' => 'annotates a member with metadata',
    'construct:auto-implemented-property' => 'defines an auto-implemented property',
    'construct:big-integer' => 'uses a big integer',
    'construct:binary-number' => 'defines a number in binary notation',
    'construct:bit-array' => 'uses or declares a bit array',
    'construct:bitwise-and-assignment' => 'combines a bitwise AND with assignment',
    'construct:bitwise-and' => 'executes a bitwise AND',
    'construct:bitwise-left-shift-assignment' => 'combines a bitwise left shift with assignment',
    'construct:bitwise-left-shift' => 'executes a bitwise left shift',
    'construct:bitwise-not' => 'executes a bitwise NOT',
    'construct:bitwise-or-assignment' => 'combines a bitwise OR with assignment',
    'construct:bitwise-or' => 'executes a bitwise OR',
    'construct:bitwise-right-shift-assignment' => 'combines a bitwise right shift with assignment',
    'construct:bitwise-right-shift' => 'executes a bitwise right shift',
    'construct:bitwise-xor-assignment' => 'combines a bitwise XOR with assignment',
    'construct:bitwise-xor' => 'executes a bitwise XOR',
    'construct:block' => 'defines a block containing a list of statements',
    'construct:boolean' => 'defines or uses a boolean value',
    'construct:boxing' => 'uses boxing',
    'construct:break' => 'breaks from a loop',
    'construct:byte' => 'uses an unsigned 8-bit integer',
    'construct:catch' => 'catches an exception',
    'construct:char' => 'uses a character',
    'construct:checked-arithmetic' => 'uses checked arithmetic (which guards against overflows)',
    'construct:class' => 'defines a class',
    'construct:collection-initializer' => 'sets a collection\'s values via an initializer',
    'construct:command' => 'defines a command',
    'construct:comment' => 'defines a comment',
    'construct:comparison-chaining' => 'chains comparison calls',
    'construct:comparison' => 'compares two values for their relative order',
    'construct:complex-number' => 'uses a complex number',
    'construct:computed-string' => 'defines a computed string',
    'construct:concatenation' => 'concatenates values',
    'construct:conditional-access' => 'accesses a method conditionally',
    'construct:conditional-operator' => 'uses a ternary conditional operator',
    'construct:conditional' => 'executes code conditionally',
    'construct:constant' => 'defines a constant (immutable) value',
    'construct:constructor' => 'defines a constructor',
    'construct:continue' => 'continues to the next iteration of a loop',
    'construct:conversion-operator' => 'defines a conversion operator',
    'construct:copy' => 'copies a value',
    'construct:coroutine' => 'defines or uses a coroutine',
    'construct:custom-attribute' => 'defines a custom attribute',
    'construct:date-time' => 'uses a value that represents a combination of date and time',
    'construct:date' => 'uses va value that represents a date (no time)',
    'construct:decimal' => 'uses a 128-bit floating-point number',
    'construct:decrement' => 'decrements a value',
    'construct:default-interface-implementation' => 'defines default implementation in an interface',
    'construct:default' => 'defines a default value (e.g. for a parameter)',
    'construct:destructuring' => 'decontructs a value into its parts',
    'construct:dictionary-comprehension' => 'creates a dictionary via a comprehension',
    'construct:dictionary' => 'uses/defines a dictionary/map',
    'construct:discard' => 'uses the special discard value',
    'construct:divide-assignment' => 'combines division with assignment',
    'construct:divide' => 'uses division',
    'construct:do-while-loop' => 'uses a `do-while` loop',
    'construct:double' => 'uses a 64-bit floating-point number',
    'construct:else' => 'defines an else branch',
    'construct:enum' => 'defines or uses an enum (enumeration of values)',
    'construct:equality' => 'compares the equality of two values',
    'construct:error' => 'defines or uses an error',
    'construct:event' => 'defines or uses events',
    'construct:exception' => 'defines or uses exceptions',
    'construct:explicit-conversion' => 'converts from one type to another type explicitly',
    'construct:explicit-import' => 'imports only select functionality',
    'construct:exponentiation' => 'calculates the exponentiation of a value',
    'construct:expression-bodied-member' => 'defines an expression-bodied member',
    'construct:extension-method' => 'defines an extension method',
    'construct:field-access' => 'accesses a field',
    'construct:field' => 'defines a field',
    'construct:finally' => 'uses finally to ensure that a specific code block always runs',
    'construct:flags-enum' => 'defines or uses a flag enum',
    'construct:float' => 'uses a 32-bit floating-point number',
    'construct:floating-point-number' => 'uses a floating-point number',
    'construct:for-loop' => 'uses a `for` loop',
    'construct:foreach' => 'uses a `foreach` loop',
    'construct:function-overloading' => 'uses function overloading',
    'construct:function' => 'defines a function',
    'construct:generator' => 'defines a generator function or method',
    'construct:generic-function' => 'defines a function that is parameterized with one or more types',
    'construct:generic-method' => 'defines a method that is parameterized with one or more types',
    'construct:generic-type' => 'defines type that is parameterized with one or more types',
    'construct:getter' => 'defines a getter',
    'construct:global-function' => 'defines a function that is available globally',
    'construct:global-variable' => 'defines a variable that is available globally',
    'construct:header' => 'defines a header file',
    'construct:hexadecimal-number' => 'defines a number in hexadecimal notation',
    'construct:if' => 'uses an `if` statement',
    'construct:implicit-conversion' => 'converts from one type to another type implicitly',
    'construct:implicit-loop' => 'loops over a collection of values implicitly',
    'construct:implicit-return' => 'returns a value implicitly',
    'construct:import' => 'imports functionality implemented elsewhere (e.g. from a namespace/module)',
    'construct:increment' => 'increments a value',
    'construct:index-operator' => 'defines an operator for indexing an object',
    'construct:indexer' => 'defines or uses an indexer',
    'construct:indexing' => 'accesses a value by index',
    'construct:inequality' => 'compares the inequality of two values',
    'construct:infix-operator' => 'defines an infix operator',
    'construct:initialization' => 'initializes an object after creation',
    'construct:initializer-list' => 'initializes the values of an object\'s fields',
    'construct:initializer' => 'initializes an object',
    'construct:instance' => 'creates or uses an instance of a type',
    'construct:instantiation' => 'creates an instance of a type',
    'construct:int' => 'uses a signed 32-bit integer',
    'construct:integral-number' => 'uses an integral number (integer)',
    'construct:interface' => 'defines an interface',
    'construct:invocation' => 'invokes a method/function',
    'construct:iterator' => 'defines a function or method that can be iterated over',
    'construct:jagged-array' => 'uses a jagged array (an array of arrays)',
    'construct:lambda' => 'defines a lambda (aka an "anonymous function")',
    'construct:linked-list' => 'uses a linked list',
    'construct:linq' => 'uses LINQ',
    'construct:list-comprehension' => 'builds a list via a comprehension',
    'construct:list' => 'uses a list',
    'construct:local-function' => 'defines a local function',
    'construct:local-variable' => 'defines a local variable',
    'construct:lock' => 'uses a lock',
    'construct:logical-and' => 'executes a logical AND',
    'construct:logical-not' => 'executes a logical NOT',
    'construct:logical-or' => 'executes a logical OR',
    'construct:long' => 'uses a signed 64-bit integer',
    'construct:loop' => 'defines a loop',
    'construct:macro' => 'defines a macro',
    'construct:membership-test' => 'tests a value for membership in another value',
    'construct:metatable' => 'defines a metatable',
    'construct:method-chaining' => 'chains several method calls',
    'construct:method-overloading' => 'uses method overloading',
    'construct:method-override' => 'defines an overridden method',
    'construct:method' => 'defines a method',
    'construct:module' => 'defines a module (grouping of code)',
    'construct:modulo-assignment' => 'combines division remainder with assignment',
    'construct:modulo' => 'uses division remainder',
    'construct:multi-dimensional-array' => 'uses an array with multiple dimensions',
    'construct:multiline-string' => 'defines a multiline string',
    'construct:multiple-assignment' => 'assigns multiple values at once',
    'construct:multiple-dispatch' => 'uses multiple dispatch',
    'construct:multiply-assignment' => 'combines multiplication with assignment',
    'construct:multiply' => 'uses multiplication',
    'construct:named-argument' => 'passes an argument by name',
    'construct:namespace' => 'defines a namespace (grouping of code)',
    'construct:nested-function' => 'defines a nested function',
    'construct:nested-type' => 'defines a nested type',
    'construct:nesting' => 'uses nesting',
    'construct:nint' => 'uses a signed platform-specific integer (32- or 64-bit)',
    'construct:nuint' => 'uses an unsigned platform-specific integer (32- or 64-bit)',
    'construct:null' => 'uses null/nil to represents the absence of a value',
    'construct:nullability' => 'deals with null/nil values',
    'construct:number' => 'uses a number (signed or unsigned)',
    'construct:object-initializer' => 'sets an object\'s values via an initializer',
    'construct:octal-number' => 'defines a number in octal notation',
    'construct:operator-overloading' => 'uses operator overloading',
    'construct:option' => 'uses an option type',
    'construct:optional-parameter' => 'defines an optional parameter',
    'construct:overflow' => 'uses arithmetic overflow',
    'construct:parameter' => 'defines a parameter',
    'construct:parenthesized-expression' => 'encloses an expression in parentheses',
    'construct:pattern-matching' => 'uses pattern matching',
    'construct:pattern' => 'defines a pattern uses in pattern matching',
    'construct:pipe-backward' => 'uses a backward pipe',
    'construct:pipe-forward' => 'uses a forward pipe',
    'construct:pipeline' => 'defines a pipeline',
    'construct:point-free' => 'defines functions without the arguments they operate on',
    'construct:pointer' => 'uses a pointer',
    'construct:postfix-decrement' => 'decrements a value using postfix notation',
    'construct:postfix-increment' => 'increments a value using postfix notation',
    'construct:prefix-decrement' => 'decrements a value using prefix notation',
    'construct:prefix-increment' => 'increments a value using prefix notation',
    'construct:print' => 'prints a value to the console',
    'construct:property' => 'defines a property (getter/setter)',
    'construct:query-expression' => 'queries data via an expression',
    'construct:queue' => 'uses a queue',
    'construct:range' => 'defines a range',
    'construct:read-only' => 'defines a read-only value',
    'construct:record' => 'defines a record',
    'construct:regular-expression' => 'defines or uses a regular expression',
    'construct:result' => 'uses a result type',
    'construct:return-type' => 'defines the return type of a function or method',
    'construct:return' => 'returns from a function/method',
    'construct:sbyte' => 'uses a signed 8-bit integer',
    'construct:scientific-notation-number' => 'defines a number in scientific notation',
    'construct:set-comprehension' => 'creates a set via a comprehension',
    'construct:set' => 'uses a set',
    'construct:setter' => 'defines a setter',
    'construct:short' => 'uses a signed 16-bit integer',
    'construct:slice' => 'uses a slice',
    'construct:stack' => 'uses a stack',
    'construct:static-field' => 'defines a static field',
    'construct:static-method' => 'defines a static method',
    'construct:string-formatting' => 'builds a string via a format string',
    'construct:string-interpolation' => 'defines an interpolated string',
    'construct:string' => 'defines a string',
    'construct:struct' => 'defines a struct',
    'construct:subtract-assignment' => 'combines subtraction with assignment',
    'construct:subtract' => 'uses subtraction',
    'construct:sum-type' => 'defines a sum type',
    'construct:switch' => 'uses a `switch`',
    'construct:table' => 'defines a table',
    'construct:template-alias' => 'defines an alias for a template',
    'construct:template-parameter' => 'defines a template parameter',
    'construct:template' => 'defines a template',
    'construct:throw' => 'throws an exception',
    'construct:time' => 'uses an object that represents the time',
    'construct:try' => 'handles an exception explicitly',
    'construct:tuple' => 'uses a tuple',
    'construct:type-alias' => 'defines an alias for a type',
    'construct:type-conversion' => 'converts (casts) a value to another type',
    'construct:type-extension' => 'extends a type with new functionality',
    'construct:type-inference' => 'infers the type of a value/function automatically',
    'construct:type-test' => 'test if a value has a specific type',
    'construct:uint' => 'uses an unsigned 32-bit integer',
    'construct:ulong' => 'uses an unsigned 64-bit integer',
    'construct:unary-minus' => 'uses a unary minus',
    'construct:unary-plus' => 'uses a unary plus',
    'construct:underscored-number' => 'uses a number with underscores as its digit separators',
    'construct:union-type' => 'defines a union type',
    'construct:user-defined-exception' => 'defines a custom, user-defined exception',
    'construct:ushort' => 'uses an unsigned 16-bit integer',
    'construct:using-directive' => 'uses code from another file',
    'construct:using-statement' => 'assigns and disposes a value via the using statement',
    'construct:varargs' => 'defines a parameter that supports passing in zero or more values',
    'construct:variable' => 'declares variable',
    'construct:vector' => 'uses a vector',
    'construct:verbatim-string' => 'uses a verbatim string (no escape sequences)',
    'construct:virtual-method' => 'defines a virtual method',
    'construct:visibility-modifiers' => 'specifies the visibility of a construct (e.g. a method or class)',
    'construct:while-loop' => 'uses a `while` loop',
    'construct:yield' => 'yields a value in a loop lazily',
    'paradigm:declarative' => 'uses declarative programming.',
    'paradigm:functional' => 'uses functional programming.',
    'paradigm:generic' => 'uses generic programming.',
    'paradigm:imperative' => 'uses imperative programming.',
    'paradigm:logic' => 'uses logic programming.',
    'paradigm:meta' => 'uses metaprogramming.',
    'paradigm:object-oriented' => 'uses object-oriented programming.',
    'paradigm:procedural' => 'uses procedural programming.',
    'paradigm:reflective' => 'uses reflective programming.',
    'paradigm:stack-oriented' => 'uses stack-oriented programming.',
    'technique:bit-manipulation' => 'manipulates bits, usually via bitwise operators (e.g. AND, XOR or left shift)',
    'technique:bit-shifting' => 'shifts bits in a number',
    'technique:boolean-logic' => 'executes boolean logic (AND, OR, NOT)',
    'technique:composition' => 'uses composition',
    'technique:concurrency' => 'runs code concurrently',
    'technique:enumeration' => 'enumerates over values',
    'technique:error-handling' => 'handles errors',
    'technique:exceptions' => 'catches or throws exceptions',
    'technique:function-composition' => 'uses function composition',
    'technique:generator' => 'uses a generator',
    'technique:generators' => 'uses generators',
    'technique:higher-order-functions' => 'uses higher-order functions',
    'technique:immutability' => 'uses immutability',
    'technique:immutable-collection' => 'uses a collection whose contents are immutable',
    'technique:inheritance' => 'uses inheritance',
    'technique:laziness' => 'produces values lazily, only when needed',
    'technique:locks' => 'uses locks to get exclusive access to resources',
    'technique:looping' => 'uses loops',
    'technique:math' => 'uses math',
    'technique:memory-management' => 'manages memory',
    'technique:ordering' => 'orders data',
    'technique:parallelism' => 'runs code in parallel',
    'technique:parser' => 'parses data',
    'technique:pointers' => 'uses pointers',
    'technique:randomness' => 'uses randomness',
    'technique:recursion' => 'uses recursion',
    'technique:regular-expression' => 'uses regular expressions',
    'technique:short-circuiting' => 'uses short-circuiting to prevent unnecessary evaluation',
    'technique:sorted-collection' => 'uses a collection whose elements are always sorted',
    'technique:sorting' => 'sorts data',
    'technique:tail-call-optimization' => 'uses tail-call optimization for efficient recursion',
    'technique:type-conversion' => 'converts values from one type to another type',
    'technique:unsafe' => 'uses unsafe code (for example pointer arithmetic)'
  }.freeze
  private_constant :CRITERIA, :SYSTEM_TEXT
end
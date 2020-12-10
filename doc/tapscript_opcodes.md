This document proposes new opcodes to be added to the elements network along with the taproot upgrade. The new tapscript `OP_SUCCESS` opcodes allow introducing new opcodes more cleanly than through `OP_NOP`. In this document, we propose modifying the following `OP_SUCCESS`
to have the additional semantics. We use opcodes serially `OP_SUCCESS200`, `201`... in order
to avoid conflict with bitcoin potentially using `OP_SUCESSSx`(assuming bitcoin uses those serially based on availability). 

# Resource Limits

## Changes in Taproot(Including Standardness Policy Changes)
Taproot already increases a lot of resource limitations from segwitv0, so there is no additional need to alter any of those. In particular, from BIP 342

- Script size limit: the maximum script size of 10000 bytes does not apply. Their size is only implicitly bounded by the block weight limit. 
- Non-push opcodes limit: The maximum non-push opcodes limit of 201 per script does not apply.
- Sigops limit: The sigops in tapscripts do not count towards the block-wide limit of 80000 (weighted). Instead, there is a per-script sigops budget. The budget equals 50 + the total serialized size in bytes of the transaction input's witness (including the CompactSize prefix). Executing a signature opcode (OP_CHECKSIG, OP_CHECKSIGVERIFY, or OP_CHECKSIGADD) with a non-empty signature decrements the budget by 50. If that brings the budget below zero, the script fails immediately. 
- Stack + altstack element count limit: The existing limit of 1000 elements in the stack and altstack together after every executed opcode remains. It is extended to also apply to the size of the initial stack.
- Stack element size limit: The existing limit of maximum 520 bytes per stack element remains, during the stack machine operations. There is an additional policy rule limiting the initial push size to 80 bytes.

## Additional resource limits changes in Elements

- New added opcodes `OP_MULTISCALAREXPVERIFY` for `k` base multi scalar exponentiation is counted as `50*k` units towards the SIGOPS budget. If the operation requires extra script_budget, the user must add additional witness elements to make sure that the script executes within the desired budget.

# New Opcodes for additional functionality:

## Multi-byte op-codes

We suggest the use of multi-byte opcodes for proper classification of additional opcodes and for limiting the number of OP_SUCCESSx used. In particular, a multi-byte opcode is a variable-length opcode containing an OP_SUCCESSx followed by a CscriptNum push with minimal representation. If the next opcode after OP_SUCCESS is not a push code or if the number is not a CScriptNum with minimal form, the script fails. The number pushed by the push operation serves as a selector for the operation to perform on the OP_SUCCESSx.

1. **Streaming Opcodes for streaming hashes**: There is an existing MAX_SCRIPT_ELEMENT_SIZE is 520 bytes, that is the maximum message size that can OP_SHA256 can operate on. This allows hashing on more than 520 bytes while still preserving the existing security against resource exhaustion attacks. The proposal for this is still under discussion in https://github.com/ElementsProject/elements/pull/817. We suggest the latest scheme suggested by Russel O Connor
   -  Define OP_SUCCESS200 as a multi-byte opcode OP_STREAMINGHASH with the following semantics. Execute the push opcode following OP_STREAMINGHASH, if the opcode is not a push opcode, fail.
   -  Pop the stack pop as minimal CScriptNum as n.
      1. If n=0, interpret `OP_SHA256INITIALIZE` to pop a bytestring and push SHA256 context creating by adding the bytestring to the initial SHA256 context.
      2. If n=1, interpret as `OP_SHA256UPDATE` to pop a SHA256 context and bytestring and push an updated context by adding the bytestring to the data stream being hashed.
      3. If n=2, interpret as `OP_SHA256FINALIZE` to pop a SHA256 context and bytestring and push a SHA256 hash value after adding the bytestring and completing the padding.
      4. If n=3, interpret `OP_RIPEMD160INITIALIZE` to pop a bytestring and push RIPEMD160 context creating by adding the bytestring to the initial RIPEMD160 context.
      5. If n=4, interpret as `OP_RIPEMD160UPDATE` to pop a RIPEMD160 context and bytestring and push an updated context by adding the bytestring to the data stream being hashed.
      6. If n=5, interpret as `OP_RIPEMD160FINALIZE` to pop a RIPEMD160 context and bytestring and push a RIPEMD160 hash value after adding the bytestring and completing the padding.
      7. If n=6, interpret `OP_HASH256INITIALIZE` to pop a bytestring and push HASH256 context creating by adding the bytestring to the initial HASH256 context.
      8. If n=7, interpret as `OP_HASH256UPDATE` to pop a HASH256 context and bytestring and push an updated context by adding the bytestring to the data stream being hashed.
      9. If n=8, interpret as `OP_HASH256FINALIZE` to pop a HASH256 context and bytestring and push a HASH256 hash value after adding the bytestring and completing the padding.
      10. If n=9, interpret `OP_HASH160INITIALIZE` to pop a bytestring and push HASH160 context creating by adding the bytestring to the initial HASH160 context.
      11. If n=10, interpret as `OP_HASH160UPDATE` to pop a HASH160 context and bytestring and push an updated context by adding the bytestring to the data stream being hashed.
      12. If n=11, interpret as `OP_HASH160FINALIZE` to pop a HASH160 context and bytestring and push a HASH160 hash value after adding the bytestring and completing the padding.
      13. Otherwise, fail.


2. **Transaction Introspection codes**: Transaction introspection is already possible in elements script by use of `OP_CHECKSIGFROMSTACKVERIFY`, however the current solutions are really expensive in applications like [covenants](https://github.com/sanket1729/covenants-demo). Therefore, we are not adding any new functionality by supporting introspection, only making it easier to use. The warning still remains the same as with covenants, if the user is inspecting data from parts of the transaction that are not signed, the script can cause unexpected behavior. 
   - Define `OP_SUCCESS201` as a multi-byte opcode `OP_INSPECTINPUT` with the following semantics. Execute the push opcode following `OP_INSPECTINPUT`, if the opcode is not a push opcode, fail. 
      - Pop the stack pop as minimal `CScriptNum` as `n`. Next, pop another element as minimal `CScriptNum` input index `idx`.
      1. If `n=0`, `OP_INSPECTINPUTSPENDTYPE` Push 1 byte "spend_type" onto the stack. spend_type (1) is equal to `(ext_flag * 2) + annex_present` as defined in [Modified BIP-341 SigMsg for Elements](https://gist.github.com/roconnor-blockstream/9f0753711153de2e254f7e54314f7169)
      2. If `n=1`, `OP_INSPECTINPUTOUTPOINTFLAG` Push the outpoint_flag(1) as defined in [Modified BIP-341 SigMsg for Elements](https://gist.github.com/roconnor-blockstream/9f0753711153de2e254f7e54314f7169)
      3. if `n=2`, `OP_INSPECTINPUTOUTPOINT` Push the outpoint as a tuple. First push the `txid`(32) of the `prev_out`, followed by a 4 byte push of `vout`
      4. If `n=3`, `OP_INSPECTINPUTASSET` Push the `nAsset` as a tuple, first push the assetID(32), followed by the prefix(1)
      5. If `n=4`, `OP_INSPECTINPUTVALUE` Push the `nValue` as a tuple, value(8, 32) followed by prefix,
      6. If `n=5`, `OP_INSPECTINPUTSSCRIPTPUBKEY` Push the scriptPubkey(35) onto the stack.
      7. If `n=6`, `OP_INSPECTINPUTSEQUENCE` Push the `nSequence`(4) as little-endian number. 
      8. If `n=7`, `OP_INSPECTINPUTISSUANCE` Push the assetIssuance information(74-130) if the asset has issuance, otherwise push an empty vector
      9. If `n=8`, `OP_INSPECTINPUTINDEX` Push the current input index(4) as little-endian onto the stack
      10. If `n=9`, `OP_INSPECTINPUTANNEX` Push the annex onto the stack where the annex includes the prefix(0x50). If the annex does not exist, push an empty vector
      11. Otherwise fail.
   - Define `OP_SUCCESS202` as a multi-byte opcode `OP_INSPECTCURRENTINPUT` with the following semantics. Execute the push opcode following `OP_INSPECTCURRENTINPUT`, if the opcode is not a push opcode, fail. 
      - Pop the stack pop as minimal `CScriptNum` as `n`. All the implementation is exactly the same as `OP_INSPECTINPUT`, but uses the current input instead of reading the input from stack. The names of the `OP_INSPECTINPUTx` would be replaced by `OP_INSPECTCURRENTINPUTx`
   - Define `OP_SUCCESS203` as a multi-byte opcode `OP_INSPECTOUTPUT` with the following semantics. Execute the push opcode following `OP_INSPECTOUTPUT`, if the opcode is not a push opcode, fail.
      - Pop the stack pop as minimal `CScriptNum` as `n`. Next, pop another element as minimal `CScriptNum` input index `idx`.
      1. If `n=0`, `OP_INSPECTOUTPUTASSET` Push the `nAsset` as a tuple, first push the assetID(32), followed by the prefix(1)
      2. If `n=1`, `OP_INSPECTOUTPUTVALUE` Push the `nValue` as a tuple, value(8, 32) followed by prefix
      3. If `n=2`, `OP_INSPECTOUTPUTNONCE` Push the `nNonce` as a tuple, nonce(32, 0) followed by prefix. Push empty vector for `None` nonce
      4. If `n=3`, `OP_INSPECTOUTPUTSCRIPTPUBKEY` Push the scriptPubkey(35). 
      5. Otherwise, fail
   - Define `OP_SUCCESS204` as a multi-byte opcode `OP_INSPECTTX` with the following semantics. Execute the push opcode following `OP_INSPECTTX`, if the opcode is not a push opcode, fail.
      - Pop the stack pop as minimal `CScriptNum` as `n`. 
      1. If `n=0`, `OP_INSPECTVERSION` Push the nVersion(4) as little-endian.
      2. If `n=1`, `OP_INSPECTLOCKTIME` Push the nLockTime(4) as little-endian.
      3. If `n=2`, `OP_INSPECTNUMINPUTS` Push the number of inputs(4) as little-endian
      4. If `n=3`, `OP_INSPECTNUMOUTPUTS` Push the number of outputs(4) as little-endian
      5. Otherwise, abort

3. **Signed 64-bit arithmetic opcodes:** Current operations on `CScriptNum` as limited to 4 bytes and are difficult to compose because of minimality rules. having a fixed width little operations with 8 byte signed operations helps doing calculations on amounts which are encoded as 8 byte little endian. 
   - When dealing with overflows, we explicitly return the success bit as a `CScriptNum` at the top of the stack and the result being the second element from the top. If the operation overflows, first the operands are pushed onto the stack followed by success bit. \[`a_second` `a_top`\] overflows, the stack state after the operation is \[`a_second` `a_top 0`\] and if the operation does not overflow, the stack state is \[`res 1`\]. 
   - This gives the user flexibility to deal if they script to have overflows using `OP_IF\OP_ELSE` or `OP_VERIFY` the success bit if they expect that operation would never fail. 
When defining the opcodes which can fail, we only define the success path, and assume the overflow behavior as stated above.
   - Define `OP_SUCCESS205` as a multi-byte opcode `OP_ARITH64` with the following semantics. Execute the push opcode following `OP_ARITH64`, if the opcode is not a push opcode, fail.
   - Pop the stack pop as minimal `CScriptNum` as `n`.
      1. If `n=0`, `OP_ADD64` pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push a + b onto the stack. Push 1 `CScriptNum` as success bit. Overflow behavior defined above.
      2. If `n=1`, `OP_SUB64` pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push a - b onto the stack. Push 1 `CScriptNum` as success bit. Overflow behavior defined above.
      3. If `n=2`, `OP_MUL64` pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push `a*b` onto the stack. Push 1 `CScriptNum` as success bit. Overflow behavior defined above.
      4. If `n=3`, `OP_DIV64` pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). First push remainder `a%b`(must be non-negative and less than |b|) onto the stack followed by quotient(`a//b`) onto the stack. Abort if `b=0`. Push 1 `CScriptNum` as success bit. Overflow behavior defined above.
      5. If `n=4`, `OP_LESSTHAN64`(cannot fail!), pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push ` a < b`.
      6. If `n=5`, `OP_LESSTHANOREQUAL64`(cannot fail!), pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push ` a <= b`.
      7. If `n=6`, `OP_GREATERTHAN64`(cannot fail!), pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push ` a > b`.
      8. If `n=7`, `OP_GREATERTHANOREQUAL64`(cannot fail!), pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push ` a >= b`.
      9. If `n=8`, `OP_EQUAL64`(cannot fail!), pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push ` a == b`.
      10. If `n=9`, `OP_WITHIN64`(cannot fail!), pop the first number(8 byte LE) as `x` followed another pop for `min` and `max`(8 byte LE). Push ` min<= x < max`.
      11. If `n=10`, `OP_LIMIT64`(cannot fail!), pop the first number(8 byte LE) as `x` followed another pop for `min` and `max`(8 byte LE). Push `x` if ` min < x < max`, `min` if `x <= min` and `max` if `x >= max`.      
      12. If `n=11`, `OP_AND64`(cannot fail!), pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push ` a & b`.
      13. If `n=12`, `OP_OR64`(cannot fail!), pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push ` a | b`.
      14. If `n=13`, `OP_XOR64`(cannot fail!), pop the first number(8 byte LE) as `b` followed another pop for `a`(8 byte LE). Push ` a ^ b`.
      15. If `n=14`, `OP_NOT64`(cannot fail!), pop the first number(8 byte LE) as `a`. Push `~a`.
      16. If `n=15`, `OP_LSHIFT`, pop the first number as `CScriptNum` `l`(abort if l < 0 or l > 63) followed another pop for `a` (8 byte LE). Push `a << l` preserving the sign bit. `(-1 << 3) = - 8` returns fixed 64 bits, extra-bits are discarded and sign is preserved. 
      17. If `n=16`, `OP_RSHIFT`, pop the first number as `CScriptNum` `r`(abort if r < 0 or r > 63) followed another pop for `a` (8 byte LE). Push `a >> r`.(Sign bit is preserved).
      18. Otherwise, fail.

4. **Conversion opcodes:** Methods for conversion from `CScriptNum` to `8-byte LE`, `4-byte LE`.
   - Define `OP_SUCCESS206` as a multi-byte opcode `OP_CONVERSION` with the following semantics. Execute the push opcode following `OP_CONVERSION`, if the opcode is not a push opcode, fail.
   - Pop the stack pop as minimal `CScriptNum` as `n`.
      1. If `n=0`, `OP_SCIPTNUMTOLE64` pop the stack as minimal `CSciptNum`, push 8 byte signed LE corresponding to that number.
      2. If `n=1`, `OP_LE64TOSCIPTNUM` pop the stack as a 8 byte signed LE. Convert to `CScriptNum` and push it, abort on fail.
      3. If `n=2`, `OP_LE32TOLE64` pop the stack as a 4 byte signed LE. Push the corresponding 8 byte LE number. Cannot fail, useful for conversion of version/sequence.
      4. Otherwise, fail.

5. **Crypto**: In order to allow more complex operations on elements, we introduce the following new crypto-operators.
   - Define `OP_SUCCESS207` as a multi-byte opcode `OP_CRYPTO` with the following semantics. Execute the push opcode following `OP_CRYPTO`, if the opcode is not a push opcode, fail. 
   - Pop the stack pop as minimal `CScriptNum` as `n`.
      1. If `n=0`, `OP_ECMULSCALAREXPVERIFY`, pop the top element as `k`. Then pop next elements as points `G1`(first), `G2`(second)
      ..`Gk`. Next pop `k` scalars `x1`, `x2`... `xk`. Finally pop result element as as point `Q`. Assert `x1G1+x2G2+x3G3.. xkGk == Q` This counts as `k*50` towards budget sigops. If any of `G_i`,`Q` is point at infinity fail.
      2. If `n=1`, `OP_ECNEGATE` pop a point `G`(33 bytes) from stack, push `-G` onto the stack.
      3. If `n=2`, `OP_PUSH256NUM_0`, Push 256 bit scalar value 0.
      4. If `n=3`, `OP_PUSH256NUM_`, Push 256 bit scalar value 1. 
      5. If `n=4`, `OP_SCALARADD` pop the top two stack elements(32 bytes)(`a` and `b`) as scalars, return (`(a+b)%n`) where `n` is order of secp256k1. Note that we do not error is `a>=n` or `b>=n`.
      6. If `n=5`, `OP_SCALARMUL`, pop the top two stack elements(32 bytes)(`a` and `b`) as scalars, return (`(a*b)%n`) where `n` is order of secp256k1. Note that we do not error is `a>=n` or `b>=n`.
      7. If `n=6`, `OP_SCALARNEGATE` pop a scalar(256 bits), and pushed `-a%n` onto the stack where `n` is order of secp256k1. 
      8. If `n=7`, `OP_TAPTWEAK` with the following semantics. Pop the first element as point `P`, second element as script blob `S`. Push the Taptweak on the top of stack `Q = P + H(P||S)*G`. If `|S| > MAX_ELEMENT_SIZE`, the user should use the streaming opcodes to compute the Hash function.
      9. Otherwise, abort

7. **For loop**: Introduce new writing for `OP_FOR` loops, which is effectively unrolling of the for loop with a special syntax. 
`<k> OP_FOR (S0) OP_LOOP (S1) OP_LOOP ... OP_LOOP (S(n-1)) OP_ENDFOR` is equivalent to the code
```
for (i = 0; i < n; i++){
    if (i < k)
      exec S_i
}
``` 
Script aborts if `k > n`. 
Note that we are not increasing the expressiveness of the current bitcoin script, we are providing more ergonomic ways to use it naturally. Define `OP_SUCCESS208` as `OP_FOR`, `OP_SUCCESS209` as `OP_LOOP` and `OP_SUCCESS210` as `OP_ENDFOR`. The script interpreter aborts if it finds nested for loops. 

7. **Changes to existing Opcodes**:
   - Add `OP_CHECKSIGFROMSTACK` and `OP_CHECKSIGFROMSTACKVERIFY` to follow the semantics from bip340-342 when witness program is v1. 
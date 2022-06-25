// Play on: https://cpulator.01xz.net/?sys=arm-de1soc

/*
Code written for school course in 2019. Done in 1 day, it may be low quality poorly designed and spaghetti code, I've not reviewed it since. Recently translated comments to english
This is a small calculator supporting addition, subtraction, multiplication, division. Chained operations are possible (ex: 1+2+3+5+9+14.. accumulated result shows each time we write a new operator ('+', '-', '*') or a '=').
However there are some particularities due to the way I coded the app: computation is never done when we write the second operand (ex: '4+5') but when we write a new operator ('4+4+' or '4+4=' will print 8), because only operator inputs trigger the computation of values entered before. When we write '4+', the app adds 4 to the current result, which is initially 0. This works correctly for addition but is a cause of problems when doing chained operations with different operators, especially subtraction: if we write '4-', it will actually compute '0-4' and print a very high number because the app doesn't work with signed numbers. If we want to begin with a subtraction, we have to add the first operand to the current result by doing an addition (or another op), so here 10-4 becomes '10+-4=' because the '+' adds 10 to the current value which is 0, and then the subtraction works. For chained operations we have the same problem; if we write 10+5-4, the computation will be the following: 0+10 = 10; 10-5 = 5; 4 will stay unused until we write another operator or '=', because writing the '-' actually subtracts the last entered value (5) to the current/last result (10). To fix it we can write: '10+5+-4=' or '10+5+-4-' or '10+5+0-4=". Those 3 expressions should print 11.
Also, note that entering '=' computes the last operation, print the result ans reset both the result and the input (put them to 0). If we write '=' we cannot do chained operations here-after, we have to re-enter our values.

Enter 'c' to immediately reset result and input (set to 0).
Enter 'e' to only reset the input.
*/
.syntax unified

.data
.global convtable           // conversion table of digits in 7-segments format (by index: convtable[0] == 0x3F == 7-segment value of number 0)
convtable: .byte 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, /* we add some 0 such that the array size is 16 and doesn't corrupt memory alignment for next addressable data (displaymap)*/ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
.global displaymap
displaymap: .word 0xff200020, 0xff200021, 0xff200022, 0xff200023, 0xff200030, 0xff200031, 0xff200032, 0xff200033 // array of addresses mapped to the 7-segment display

.text
.arm
.equ UARTINOUT, 0xff201000
.global _start

// See http://www.asciitable.com/ for a list of ASCII codes
_start:
    bl cleardisplay
    mov r4, #0              // r4 holds the result
    mov r5, #0              // r5 holds last input
    ldr r6, =clearentry     // r6 stores the last operation to execute when '=' has been entered (set to clearentry when there is no waiting op)
    ldr r7, =loop           // r7 is the return address after an operation (doXXX labels)
    mov r8, #0              // is 0 when no value has been entered since the last '=', is 1 otherwise (used by mul op)

loop:                       // main loop waiting for user input
    bl getch				// r0 = getch();
    cmp r0, #0x30           // 0x30 is ascii code for 0. Characters '+', '-', '*', have an ascii code lower than this value.
    bge printdigits         // jump to the code that displays input digits (if input is a digit, but also manages '=', 'c' and 'e' from there)
//testadd:
    cmp r0, #0x2B           // test if desired operation given as input is an addition (character is a '+')
    bne testsub             // if not, jump to to the test for a subtraction (could have made a jump table based on operator instead but well)
    ldr r6, =doadd          // store desired operation character code in r6 (will be used when entering '=')
doadd:
    add r4, r4, r5          // actually do the operation
    b clearentry
testsub:
    cmp r0, #0x2D           // test if desired operation is subtraction (char is '-')
    bne testmul
    ldr r6, =dosub
dosub:
    sub r4, r4, r5
    b clearentry
testmul:
    cmp r0, #0x2A           // test if desired operation is multiplication (char is '*')
    bne loop
    ldr r6, =domul
domul:
    cmp r8, #0
    moveq r4, #1            // avoid that the result stays 0 (r8 is used as boolean, is 0 after entering '=' or before any operator has been entered, becomes 1 after)
    mov r8, #1              // r8 set to 1 now that r4 has been reset
    mul r4, r4, r5          // x*0 = 0 but x*1 = x, the two lines above are used to avoid the first case
clearentry:
    mov r5, #0              // reset input
    mov r0, r4
    bl printinteger         // print the current result
    bx r7                   // return address is in r7, is =endop if a '=' has been entered, otherwise it's =loop 
printdigits:
    cmp r0, #0x39			// if value is above 0x39 (ascii code of '9'), then this may be '=' or 'c' or 'e' which is not a number
    bgt testequ
    sub r0, r0, '0'         // r0 = r0 - '0' (ascii => binary form)
    mov r1, #10
    mul r5, r5, r1          // appending a digit is done by multiplicating current value by 10 and adding this value to the new digit: entering '4' then '5' gives (4*10) + 5 = 45
    add r5, r5, r0
    mov r0, r5
    bl printinteger         // print the computed value, clear previously displayed value and do binary to 7-segment conversion
    b loop
testequ:
    cmp r0, #0x3D           // test if desired operation is just to print the last result (char is '=')
    bne testc
    ldr r7, =endop          // r7 is the return address used by clearentry
    bx r6                   // execute operation at address [r6] (one of those doXXX labels, then clearentry, or just clearentry when there is no op. Then clearentry jumps to [r7] that was just assignated to endop)
endop:                      // this code is executed after clearentry
    mov r4, #0              // reset result
    mov r8, #0              // reset the boolean state indicating if an operator has been entered (put to no-op)
    ldr r6, =clearentry     // reset r6 and r7 function pointers (no op, default behaviour)
    ldr r7, =loop
    b loop
testc:
    cmp r0, #0x63           // test if input char is 'c'
    bne teste
    mov r4, #0              // result = 0
    mov r5, #0              // input = 0
    mov r0, #0
    bl printinteger         // print 0
    b loop
teste:
    cmp r0, #0x65           // test if input char is 'e'
    bne loop
    mov r5, #0              // input = 0
    mov r0, r4
    bl printinteger         // display the current result again, instead of the last input value
    b loop                  // back to the start


/* Clear the 7-segment display */
cleardisplay:
    mov r0, #0
    ldr r1, =displaymap
    ldr r2, [r1]
    str r0, [r2]            // put word at 0xff200020 to 0x00000000
    ldr r2, [r1, #16]
    str r0, [r2]            // put word at 0xff200030 to 0x00000000
    bx lr

// Print value of register r0 on the display (decimal representation).
// I wrote this function by studying C code of the itoa function (int to ascii) and adapting only what's necessary: https://www.geeksforgeeks.org/implement-itoa/
printinteger:                   
    push {r0, lr}
    bl cleardisplay             // clear the currently displayed value
    pop {r0, lr}
    push {r4}
    mov r4, #0                  // r4 is used as a counter to avoid printing more than 8 digits
itoa_loop:
    mov r2, r0                  // r2 will hold result of r0 % 10 (modulo)
/*loopmodulo:
    cmp r2, #10
    ble endmodulo
    sub r2, r2, #10
    b loopmodulo
endmodulo:*/
    ldr r3, =-858993459
    umull r1, r3, r3, r2
    lsrs r3, r3, #3
    add r3, r3, r3, lsl #2
    sub r2, r2, r3, lsl #1
    // Computing modulo by subtracting was too slow so I used this method instead (seen on the web)
    ldr r3, =convtable
    ldrb r2, [r3, r2]           // r2 = convtable[r2]   (override result of modulo, but not needed after this line)
    ldr r3, =displaymap
    ldr r3, [r3, r4, lsl #2]    // r3 = displaymap[r4]
    push {r0, lr}
    mov r0, r2                  // preparation of arguments to call storebyte
    mov r1, r3
    bl storebyte                // should be equivalent to strb r2, [r3] if unaligned memory access was okay
    pop {r0, lr}
    ldr r3, =429496730
    smull r1, r0, r0, r3        // divide r0 by 10
    add r4, r4, #1
    cmp r0, #0                  // if r0 is 0, conversion is done
    beq end
    cmp r4, #8                  // if we are already displaying 8 digits, we won't print anymore (would overflow the mapped buffer)
    beq end
    b itoa_loop
end:
    pop {r4}
    bx lr

// Read input (one character)
getch:
	ldr r0, =UARTINOUT
l1:
	ldr r1, [r0]
    lsrs r2, r1, #15
    beq l1
    and r0, r1, #0xff
    bx lr

/* 
https://stackoverflow.com/questions/14561402/how-is-this-size-alignment-working
https://stackoverflow.com/questions/4439078/how-do-you-set-only-certain-bits-of-a-byte-in-c-without-affecting-the-rest
I initially written this function by using C code found on those web pages. May not be very optimal code though.
*/
storebyte:                  // aligned_address = address & ~(alignment - 1)
    /* arguments:
        r0 = byte to store
        r1 = address (no need to be word-aligned)
    */
    and r2, r1, #0xfffffffc // r2 = r1 & ~(4 - 1) => align address on a multiple of 4
    sub r1, r1, r2          // get index (i) of the byte using given address (r1) and aligned address (r2) (ex: 0xff200022 - 0xff200020 = 2, byte of index 2 of the word at address 0xff200020)
    lsl r1, r1, #3          // converts index into number of bits to shift (multiply by 8 = shift by 3 on the left)
    mov r3, #0xff
    lsl r3, r3, r1          // r3 = 0xff << i
    push {r4, r5}           // save nonvolatile registers
    ldr r4, [r2]            // load word at aligned address into r4
    mvn r5, r3              // r5 = ~r3
    and r4, r4, r5          // r4 &= ~(0xff << i) (clear all bits of the byte we wanna override into the word)
    lsl r0, r0, r1          // r0 = r0 << i
    and r0, r0, r3          // only keep desired byte (at index i)
    orr r4, r4, r0          // do the patch
    str r4, [r2]            // save register into memory (aligned address)
    pop {r4, r5}            // restore non-volatile registers
    bx lr
// Thus the modification of byte at address 0xff200021 can be done without accessing this address directly but by using the default aligned address (there 0xff200020) without modifying other bytes of the 32-bit word (only involved byte is written)

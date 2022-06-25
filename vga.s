// Play on: https://cpulator.01xz.net/?sys=arm-de1soc
// Documentation for the VGA buffer of DE1-SoC: http://www-ug.eecg.utoronto.ca/desl/nios_devices_SoC/dev_vga.html
// I planned to draw 2D shapes by their SDF function onto VGA display but atm it only draws the 16-bit color range repeatedly.

.global _start
_start:
	ldr r4, =0xc8000000		// r6 = start of pixel buffer (to be filled with 16-bit color data)
	ldr r5, =0xc8040000		// r7 = end of pixel buffer (I'm not sure this is correct)
	ldr r6, =0x0001			// initial color, incremented at each pixel
	
	// VGA pixel buffer: 1024 bytes/row, 2 bytes per pixel

	mov r7, #0				// column counter
	mov r8, #0				// row counter
loop:
	cmp r7, #512			// we stop after 512th pixel of the row
	beq changerow
	cmp r8, #256			// we stop after the 256th row
	beq end

	mov r0, r7
	mov r1, r8
	mov r2, r6
	bl writepixel

	add r7, r7, #1
	add r6, r6, #1			// also increment color
	b loop
changerow:
	mov r7, #0
	add r8, r8, #1
	b loop
end:
	b .

// -- WRITEPIXEL routine --------------------------------------------------------------------------------------
// r0 = x (row)
// r1 = y (column)
// r2 = pixel color (16-bit)
writepixel:
	lsl r0, r0, #1			// x * 2 (2 bytes per pixel)
	lsl r1, r1, #10			// y * 1024 (1024 bytes per row)

	add r0, r0, r1			// get offset in pixel buffer by concatenating 2*x and 1024*y
	add r0, r0, r4			// add base address to offset to get target address
	mov r1, r2				// r1 is data argument for storebytes
	mov r2, #2				// r2 is size argument for storebytes

	b storebytes			// tail call

// -- STOREBYTES routine --------------------------------------------------------------------------------------
// some ARM configurations / memory mappings do not support unaligned memory access
// this routine can be used to store 1 to 4 bytes of data (max. 1 word), given an arbitrary pointer (it does the alignment by breaking down unaligned access into 2 aligned accesses)
// !!! it does not check if [size] is between 1 to 4 (more than 4 will corrupt the result) !!!
// r0 = desired target address (no need of alignment)
// r1 = data to write
// r2 = size of data (in bytes)
storebytes:
	push {r4, r5, r6, r7}	// save non-volatile registers before using them
	mov r5, #4				// r5 is a constant value to hold '4' when use of immediate values is not supported in cpu operations
	mov r7, #1				// init r7 to 1 (for bit shifting)
	
	bic r3, r0, #3			// r3 = r1 & ~(4 - 1); // align adress to a multiple of 4 (rounded down)
	sub r4, r0, r3			// get offset of the desired address (r0) in the aligned address (r3), called the start offset
	add r4, r4, r2			
	sub r4, r5, r4 			// compute the end offset : distance (in bytes) between end of the word and end of data
	ldr r6, [r3]			// load the existing word at aligned address r3 into r6 (placeholder register)
	cmp r4, #0				// if end offset < 0, then we need to work with the next word as well because it overlaps it
	blt overlap
	// first word
	lsl r4, r4, #3			// get end offset as bits (end offset * 8)
	lsl r2, r2, #3			// get size as bits (size * 8)
	lsl r7, r7, r2			// prepare the mask to only mark bits where new data takes place, that is, size as bits
	sub r7, r7, #1			// subtract 1 to the previous value to actually toggle bits below the shifted value
	lsl r7, r7, r4			// shift the mask by end offset (as bits) to take it into account
	bic r6, r6, r7			// reverse the mask to clear bits that were marked (need to be kept in the original word, so need to be cleared in the mask), apply this mask to the original word at same time
	lsl r1, r1, r4			// shift data by end offset to align bytes to the target word
	orr r6, r6, r1			// apply data to the original word
	str r6, [r3]			// write modified word to its original address
ret:
	pop {r4, r5, r6, r7}
	bx lr
overlap:
	// first word
	add r2, r2, r4			// add end offset (negative number) to size such that size is the size of remaining data (data which overlaps on next word)
	lsl r2, r2, #3			// get size as bits (size * 8)
	lsl r7, r7, r2			// prepare the mask as previously, except we don't shift by end offset because there is no end offset when the data overlaps
	sub r7, r7, #1			// mark bits that will need to be erased from the original word to fit new data
	bic r6, r6, r7			// apply reversed mask to original word
	mov r2, #0		
	sub r2, r2, r4			// set size to size of remaining data (end offset as positive number, end offset value (r4) is discarded then, not needed anymore)
	lsl r2, r2, #3			// get size as bits (size * 8)
	lsr r4, r1, r2			// shift right data by size of remaining data (that will take place on second word) to automatically keep data fitting in the first word only
	orr r6, r6, r4			// apply data to the original word
	str r6, [r3]			// write modified word to original address
	
	// second word
	add r3, r3, #4			// add 4 to the pointer to work with next word for remaining data
	ldr r6, [r3]			// r6 receives the second word
	mov r7, #-1				// -1 is 0xffffffff (all bits as 1)
	lsr r7, r7, r2			// prepare mask to only clear left bits of the second word, according to remaining size (r2)
	and r6, r6, r7			// apply mask to original word
	lsr r2, r2, #3			// get size as bytes (size / 8)
	sub r4, r5, r2			// compute 4 - size (as bytes) to shift left remaining data to fit the second word
	lsl r4, r4, #3			// convert this computed value to bits
	lsl r1, r1, r4			// actually shift left data to fit remaining data in the destination word
	orr r6, r6, r1			// apply data to the word
	str r6, [r3]			// write modified word to the second word's pointer
	b ret
# Assembly programming
Some ARM code written in 2019 and 2022, to be played inside the [DE1-SoC emulator](https://cpulator.01xz.net/?sys=arm-de1soc).

## Files
* `quicksort.s` was school work requiring to translate quicksort from C code to ASM by hand.
* `calculator.s` is a simple calculator supporting addition, subtraction and multiplication, use the mapped 7-segment display of the emulator.
* `vga.s` is a recent idea I had to train myself but not finished. I also spent some times around the storebytes function, even if it's not very useful in this case.

### Pseudo-code for `storebytes` routine
I initially wrote this function directly in assembly, to write 1 to 4 bytes at arbitrary location (some ARM configurations require aligned access). I thought it would be simple but due to odds and quirks of my simple implementation, I rewrote it in pseudo-code first (here in C representation) then translated it in assembly by hand following the pseudo-code to keep my mind fresh.

```C
void storebytes(uint32_t desired_addr, uint32_t data, uint32_t size)
{
    uint32_t addr = uint32_t(desired_addr) & ~(4 - 1);                  // Align the address to a multiple of 4 (a word)
    uint32_t start_offset = desired_addr - addr;                        // Start Offset is the index of the desired address in the aligned pointer
    uint32_t end_offset = 4 - (start_offset + size);

    uint32_t old = *(uint32_t*)addr;                                    // obtain the old value we will patch

    if (end_offset < 0)
    {
        size += end_offset;										        // cut size to fit the word only
        uint32_t old_mask = ((1 << (size*8)) - 1);				        // bits where new data takes place are set to 1
        old &= ~old_mask;                                               // clear those bits (using reverse mask) to avoid corrupting data by future OR operation
        size = -end_offset;                                             // set size to size of remaining data
        *(uint32_t*)addr = old | (data >> (size*8));                    // shift right by size of remaining data to only keep data fitting in the first word
        
        // remaining data
        old = *(uint32_t*)(addr + 4)                                    // switch to next word
        old &= (-1 >> (size*8));                                        // clear all bits of [size] bytes in old (-1 is 0xffffffff, then we shift right to get zeros on the left part that will receive new value)
        *(uint32_t*)addr = old | (data << (4 - (size*8)));              // shift left data from 4-size to keep only the remaining data
    }
    else
    {
        uint32_t old_mask = ((1 << (size*8)) - 1) << (end_offset * 8);  // bits where new data takes place are set to 1
        old &= ~old_mask;                                               // clear those bits (using reverse mask) to avoid corrupting data by future OR operation
        *(uint32_t*)addr = old | (data << (end_offset*8));
    }
}
```
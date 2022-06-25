// Andrea Garcia
// https://cpulator.01xz.net/?sys=arm-de1soc

.syntax unified

.data
.global array
array:
.word 0x2, 0x6, 0x3, 0x8, 0x5, 0x4, 0x1, 0x9, 0x7

.text
.arm
.equ    SIZE, 9
.global quicksort
.global _start

_start:
    ldr r0, =array
    mov r1, #0
    mov r2, SIZE-1
    bl quicksort                // quicksort(array, 0, SIZE-1);
    b .                         // while (true) {}

quicksort:
    push {r4, r5, r6, r7}       // sauvegarde sur pile des registres non-volatiles qui seront utilisés
    cmp r1, r2
    bge end                     // if (left >= right) return
    mov r3, r1                  // int i = left
    mov r4, r2                  // int j = right
    ldr r5, [r0, r3, lsl #2]    // int pivot = target[i]
loop0:
    cmp r3, r4
    bge endloop0                // while (i < j)
    ldr r6, [r0, r3, lsl #2]    // int tmpi = target[i]
loop1:
    cmp r6, r5
    bge endloop1                // while (tmpi < pivot)
    add r3, r3, #1              // i = i + 1
    ldr r6, [r0, r3, lsl #2]    // tmpi = target[i]
    b loop1
endloop1:
    ldr r7, [r0, r4, lsl #2]    // int tmpj = target[j]
loop2:
    cmp r5, r7
    bge endloop2                // while (pivot < tmpj)
    sub r4, r4, #1              // j = j - 1
    ldr r7, [r0, r4, lsl #2]    // tmpj = target[j]     
    b loop2
endloop2:
    cmp r3, r4
    bge endif                   // if (i < j)
    str r7, [r0, r3, lsl #2]    // target[i] = tmpj
    str r6, [r0, r4, lsl #2]    // target[j] = tmpi
    add r3, r3, #1              // i = i + 1
    sub r4, r4, #1              // j = j - 1
endif:
    b loop0                     // saut au début de la boucle (loop0)
endloop0:                           
    // rappel: quicksort(a, b, c) <=> quicksort(r0, r1, r2) (convention d'appel)
    push {r2, lr}               // sauvegarde de r2 avant écrasement par sub, et de lr avant écrasement par bl
    sub r2, r3, #1              // r2 = i - 1
    bl quicksort                // quicksort(target, left, i-1)
    pop {r2, lr}                // restauration de r2 et lr
    add r1, r4, #1              // r1 = j + 1
    push {lr}
    bl quicksort                // quicksort(target, j+1, right)
    pop {lr}
end: 
    pop {r4, r5, r6, r7}        // restauration des registres non-volatiles
    bx lr                       // retour à l'adresse pointée par lr
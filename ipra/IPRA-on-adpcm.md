

IRPA example can not continue use the SNU Real time benchmark _quantl function

- Inlining, so there is no call about abs
abs is a simple function and can be directly inlined into three instructions:
	movl	%edi, %eax
	negl	%eax
	cmovsl	%edi, %eax



The following code shows some cases about enable/disable IPRA


```asm
encode:                                 # @encode
	.cfi_startproc
# %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movl	$4294967168, %r10d              # imm = 0xFFFFFF80
	movslq	tqmf(%rip), %rax
...
	cmovsl	%r10d, %r15d
...
	popq	%rbx

```

No IPRA
```asm
encode:                                 # @encode
	.cfi_startproc
# %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	pushq	%rax
	.cfi_def_cfa_offset 64
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movl	$4294967168, %r14d              # imm = 0xFFFFFF80
	movslq	tqmf(%rip), %rax
...
	movl	$4294967168, %edx               # imm = 0xFFFFFF80
	cmovsl	%edx, %r13d
...
	addq	$8, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
```


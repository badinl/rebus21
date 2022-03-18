# rebus21
*ReBUS... again.*

Thought I'd upload for posterity my final assignment for last year's Compilatori (Compilers) course in the Computer Engineering master's degree @ DEI UniPD. Sadly the course won't be offered again, but it was lots of fun - can't say the same for many other courses I took :p

This is a toy compiler that outputs three-address code starting from Rebus source code. For example, this back-of-a-handkerchief grade sourcecode prints the base cases and first 10 inductive steps of the Fibonacci sequence:

```
int a = 0, b = 1, c;
print a;
print b;
int i = 0;
while(i < 10) {
c = b + a;
a = b;
b = c;
print c;
}
```

Details on the syntax are in the report file (Italian only), together with descriptions of the lexer/parser implementation and choices made. Flex and Bison are used for lexical and syntax analysis. The syntax analyzer makes use of some "interesting" techniques (short-circuit code and backpatching).

From the example above, the compiler would generate the following 3AC (with line numbers):

```
0: t0 = 0
1: int s0
2: s0 = t0
3: t1 = 1
4: int s1
5: s1 = t1
6: int s2
7: print s0
8: print s1
9: t2 = 0
10: int s3
11: s3 = t2
12: if s3 < 10 goto 14
13: goto 20
14: t3 = s1 + s0
15: s2 = t3
16: s0 = s1
17: s1 = s2
18: print s2
19: goto 12
```

As you can see, this 3AC is quite unoptimized (indeed, optimization was not a project requirement, and the code as-is already netted me a more-than-maximum score on the project, so I clearly prioritized other aspects).

Other instances of poor optimization are related to short-circuit code. This is an excerpt from the first example found in the report file:

```
2: if s0 < 100 goto 8
3: goto 4
4: if s0 > 200 goto 6
5: goto 10
6: if s0 != s1 goto 8
7: goto 10
```

Clearly, you can cut these lines in half! Not sure though if it's possible to do so in one pass, which was a project requirement.

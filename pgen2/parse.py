# Copyright 2004-2005 Elemental Security, Inc. All Rights Reserved.
# Licensed to PSF under a Contributor Agreement.

"""Parser engine for the grammar tables generated by pgen.

The grammar table must be loaded first.

See Parser/parser.c in the Python distribution for additional info on
how this parsing engine works.
"""

from mycpp.mylib import log
_ = log

from typing import TYPE_CHECKING, Optional, Any, List
from pgen2.pnode import PNode, PNodeAllocator

if TYPE_CHECKING:
  from _devbuild.gen.syntax_asdl import Token
  from pgen2.grammar import Grammar, dfa_t

# Duplicated to avoid dependency
# from pgen2 import token

NT_OFFSET = 256


class ParseError(Exception):
    """Exception to signal the parser is stuck."""

    def __init__(self, msg, type_, tok):
        # type: (str, int, Token) -> None
        self.msg = msg
        self.type = type_
        self.tok = tok

    def __repr__(self):
        # type: () -> str
        return "%s: type=%d, tok=%r" % (self.msg, self.type, self.tok)


class _StackItem(object):
  def __init__(self, dfa, state, node):
    # type: (dfa_t, int, PNode) -> None
    self.dfa = dfa
    self.state = state
    self.node = node


class Parser(object):
    """Parser engine.

    The proper usage sequence is:

    p = Parser(grammar, [converter])  # create instance
    p.setup(start)                    # prepare for parsing
    <for each input token>:
        if p.addtoken(...):           # parse a token; may raise ParseError
            break
    root = p.rootnode                 # root of abstract syntax tree

    A Parser instance may be reused by calling setup() repeatedly.

    A Parser instance contains state pertaining to the current token
    sequence, and should not be used concurrently by different threads
    to parse separate token sequences.

    See driver.py for how to get input tokens by tokenizing a file or
    string.

    Parsing is complete when addtoken() returns True; the root of the
    abstract syntax tree can then be retrieved from the rootnode
    instance variable.  When a syntax error occurs, addtoken() raises
    the ParseError exception.  There is no error recovery; the parser
    cannot be used after a syntax error was reported (but it can be
    reinitialized by calling setup()).
    """

    def __init__(self, grammar):
        # type: (Grammar) -> None
        """Constructor.

        The grammar argument is a grammar.Grammar instance; see the
        grammar module for more information.

        The parser is not ready yet for parsing; you must call the
        setup() method to get it started.

        A concrete syntax tree node is a (type, value, context, nodes)
        tuple, where type is the node type (a token or symbol number),
        value is None for symbols and a string for tokens, context is
        None or an opaque value used for error reporting (typically a
        (lineno, offset) pair), and nodes is a list of children for
        symbols, and None for tokens.

        An abstract syntax tree node may be anything; this is entirely
        up to the converter function.
        """
        self.grammar = grammar
        self.rootnode = None  # type: Optional[PNode]
        self.stack = [] # type: List[_StackItem]
        self.pnode_alloc = None # type: Optional[PNodeAllocator]

    def setup(self, start, pnode_alloc):
        # type: (int, PNodeAllocator) -> None
        """Prepare for parsing.

        This *must* be called before starting to parse.

        The optional argument is an alternative start symbol; it
        defaults to the grammar's start symbol.

        You can use a Parser instance to parse any number of programs;
        each time you call setup() the parser is reset to an initial
        state determined by the (implicit or explicit) start symbol.
        """
        self.pnode_alloc = pnode_alloc
        newnode = self.pnode_alloc.NewPNode(start, None)
        # Each stack entry is a tuple: (dfa, state, node).
        self.stack = [_StackItem(self.grammar.dfas[start], 0, newnode)]
        self.rootnode = None

    def addtoken(self, typ, opaque, ilabel):
        # type: (int, Token, int) -> bool
        """Add a token; return True iff this is the end of the program."""
        # Loop until the token is shifted; may raise exceptions

        # Andy NOTE: This is not linear time, i.e. a constant amount of work
        # for each token?  Is it O(n^2) as the ANTLR paper says?
        # Do the "accelerators" in pgen.c have anything to do with it?

        while True:
            top = self.stack[-1]
            states, _ = top.dfa
            state = top.state

            arcs = states[state]

            # Look for a state with this label
            found = False
            for ilab, newstate in arcs:
                t = self.grammar.labels[ilab]
                if ilabel == ilab:
                    # Look it up in the list of labels
                    assert t < NT_OFFSET, t
                    # Shift a token; we're done with it
                    self.shift(typ, opaque, newstate)
                    # Pop while we are in an accept-only state
                    state = newstate
                     
                    while True:
                        # mycpp: rewrite of tuple-in-list comparison
                        if len(states[state]) != 1:
                            break

                        s0, s1 = states[state][0]
                        if s0 != 0 or s1 != state:
                            break

                        self.pop()
                        if len(self.stack) == 0:
                            # Done parsing!
                            return True
                        top = self.stack[-1]
                        states, _ = top.dfa
                        state = top.state

                    # Done with this token
                    return False
                elif t >= NT_OFFSET:
                    # See if it's a symbol and if we're in its first set
                    itsdfa = self.grammar.dfas[t]
                    _, itsfirst = itsdfa
                    if ilabel in itsfirst:
                        # Push a symbol
                        self.push(t, opaque, self.grammar.dfas[t], newstate)
                        found = True
                        break # To continue the outer while loop

            if not found:
                # Note: this condition was rewritten for mycpp tarnslation.
                # if (0, state) in arcs:
                #   ...
                # else:
                #   ...
                found2 = False
                for left, right in arcs:
                    if left == 0 and right == state:
                        # An accepting state, pop it and try something else
                        self.pop()
                        if len(self.stack) == 0:
                            # Done parsing, but another token is input
                            raise ParseError("too much input", typ, opaque)
                        found2 = True

                if not found2:
                    # No success finding a transition
                    raise ParseError("bad input", typ, opaque)

    def shift(self, typ, opaque, newstate):
        # type: (int, Token, int) -> None
        """Shift a token.  (Internal)"""
        top = self.stack[-1]
        newnode = self.pnode_alloc.NewPNode(typ, opaque)
        top.node.AddChild(newnode)
        self.stack[-1].state = newstate

    def push(self, typ, opaque, newdfa, newstate):
        # type: (int, Token, dfa_t, int) -> None
        """Push a nonterminal.  (Internal)"""
        top = self.stack[-1]
        newnode = self.pnode_alloc.NewPNode(typ, opaque)
        self.stack[-1].state = newstate
        self.stack.append(_StackItem(newdfa, 0, newnode))

    def pop(self):
        # type: () -> None
        """Pop a nonterminal.  (Internal)"""
        top = self.stack.pop()
        newnode = top.node
        if len(self.stack):
            top2 = self.stack[-1]
            top2.node.AddChild(newnode)
        else:
            self.rootnode = newnode

" Vim syntax file
" Language:    NExT (Noun Expression Tree)
" Maintainer:  Billy Lyrical
" Filenames:   *.nx *.nxt

if exists("b:current_syntax")
  finish
endif

syn case match

" Comments
syn match nxtComment "#.*$"

" Nouns (CamelCase)
syn match nxtNoun "[A-Z][a-zA-Z0-9_]*"

" Adjectives (snake_case, may contain hyphens)
syn match nxtAdj "[a-z][a-zA-Z0-_-]*"

" Brackets
syn match nxtBrack "[\[\]()]"

" Strings
syn region nxtString start='"' end='"' contains=nxtStringEscape
syn match nxtStringEscape "\\[nrt\\\"]"

" Numbers
syn match nxtInteger "\<[0-9]\+\>"
syn match nxtFloat "\<[0-9]\+\.[0-9]\+\>"

" Booleans
syn keyword nxtBoolean true false

" Symbols
syn match nxtSymbol "@[a-zA-Z_][a-zA-Z0-9_]*"

" List brackets (inside adjective values, distinguished by context)
syn match nxtListBrack "[\[\]]"

" Template syntax (.nxt files)
syn match nxtVar "${[^}]*}"
syn match nxtDefault "${[^}]*:[^}]*}"

" Template directives
syn match nxtDirective "%[A-Z][a-zA-Z0-9_]*"
syn match nxtDirective "%[a-z][a-zA-Z0-_-]*"

" Highlighting links
hi def link nxtComment    Comment
hi def link nxtNoun       Type
hi def link nxtAdj        Identifier
hi def link nxtBrack      Delimiter
hi def link nxtString     String
hi def link nxtStringEscape Special
hi def link nxtInteger    Number
hi def link nxtFloat      Float
hi def link nxtBoolean    Boolean
hi def link nxtSymbol     Constant
hi def link nxtVar        PreProc
hi def link nxtDefault    PreProc
hi def link nxtDirective  PreProc

let b:current_syntax = "nxt"

/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

/* counter for nested comment depth */
int comment_depth;

/* boolean for null char in string */
bool str_nul_char;
/* boolean for string too long */
bool str_too_long;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

%}

/*
 * Define names for regular expressions here.
 */

DIGIT    [0-9]
LOWERCASE   [a-z]
UPPERCASE   [A-Z]
IDENTIFIER    ({LOWERCASE}|{UPPERCASE}|[_]|{DIGIT})
TYPE_ID   {UPPERCASE}{IDENTIFIER}*
OBJECT_ID   {LOWERCASE}{IDENTIFIER}*
KEYWORD    ({LOWERCASE}|{UPPERCASE})+
WHITESPACE    [ \t\r\f\v]+
SINGLE_OPS    [+-/*<=~.@:)(}{,;]

DARROW          =>
LE             <=
ASSIGN          <-

%x COMMENT
%x STRING
%%


\n { curr_lineno++; }

 /*
  *  Comments
  */
"--"[^\n]*    {/* if no \n at the end */}
"--"[^\n]*"\n" { curr_lineno++; }


<INITIAL>"(*" {
  comment_depth = 1;
  BEGIN(COMMENT);
}

<INITIAL>"*)" {
  cool_yylval.error_msg = "Unmatched *)";
  return ERROR;
}

<COMMENT>"(*"        { comment_depth++; }
<COMMENT>"*"+")"     {
    comment_depth--;
    if (comment_depth == 0)
        BEGIN(INITIAL);
}
<COMMENT>\n          { curr_lineno++; }
<COMMENT>.           /* eat everything else */

<COMMENT><<EOF>> {
    cool_yylval.error_msg = "EOF in comment";
    BEGIN(INITIAL);
    return ERROR;
}

 /*
  * Strings
  */

  /* single character string */
<INITIAL>"'"[^'\n]"'" {
  if (yytext[1] == '\0') {
      cool_yylval.error_msg = "String contains null character";
      return ERROR;
  }
  string_buf[0] = yytext[1];
  string_buf[1] = 0;
  cool_yylval.symbol = stringtable.add_string(string_buf);
  return STR_CONST;
}

<INITIAL>\" {
    str_too_long = false;
    str_nul_char = false;
    string_buf_ptr = string_buf;
    BEGIN(STRING);
}

 /* Normal characters inside string */
<STRING>[^\\\"\n]+ {
    if (memchr(yytext, '\0', yyleng)) {
      str_nul_char = true;
    }

    if (string_buf_ptr + yyleng >= string_buf + MAX_STR_CONST) {
        str_too_long = true;
    } else {
      memcpy(string_buf_ptr, yytext, yyleng);
      string_buf_ptr += yyleng;
    }
}

 /* Escaped characters */
<STRING>\\(.|\n) {
  if (string_buf_ptr + 1 >= string_buf + MAX_STR_CONST) {
    str_too_long = true;
  } else {
    char c = yytext[1];
    switch (c) {
      case '\n': curr_lineno++; *string_buf_ptr++ = '\n'; break;
      case 'b':  *string_buf_ptr++ = '\b'; break;
      case 't':  *string_buf_ptr++ = '\t'; break;
      case 'n':  *string_buf_ptr++ = '\n'; break;
      case 'f':  *string_buf_ptr++ = '\f'; break;
      case '\0': str_nul_char = true; break;
      default:   *string_buf_ptr++ = c; break;
    }
  }
}

 /* closing quote */
<STRING>"\"" {
    if (str_nul_char == true) {
      cool_yylval.error_msg = "String contains null character";
      BEGIN(INITIAL);
      return ERROR;
    }
    if (str_too_long == true) {
      cool_yylval.error_msg = "String constant too long";
      BEGIN(INITIAL);
      return ERROR;
    }

    *string_buf_ptr = 0;
    cool_yylval.symbol = stringtable.add_string(string_buf);
    BEGIN(INITIAL);
    return STR_CONST;
}

 /* error cases */
<STRING>\n {
    cool_yylval.error_msg = "Unterminated string constant";
    BEGIN(INITIAL);
    return ERROR;
}

<STRING><<EOF>> {
    cool_yylval.error_msg = "EOF in string constant";
    BEGIN(INITIAL);
    return ERROR;
}

 /*
  *  Operators
  */
{DARROW}		{ return (DARROW); }
{ASSIGN}    { return (ASSIGN); }
{LE}        { return (LE); }

 /*
  * single char operators
  */
{SINGLE_OPS}   { return yytext[0]; }



 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

[t][rR][uU][eE] {
  cool_yylval.symbol = stringtable.add_string(yytext);
  cool_yylval.boolean = true;
  return BOOL_CONST;
}

[f][aA][lL][sS][eE] {
  cool_yylval.symbol = stringtable.add_string(yytext);
  cool_yylval.boolean = false;
  return BOOL_CONST;
}

 /*
  * class
  */
[cC][lL][aA][sS][sS] {
  stringtable.add_string(yytext);
  return CLASS;
}

 /*
  * else
  */
[eE][lL][sS][eE] {
  stringtable.add_string(yytext);
  return ELSE;
}

 /*
  * fi
  */
[fF][iI] {
  stringtable.add_string(yytext);
  return FI;
}

 /*
  * if
  */
[iI][fF] {
  stringtable.add_string(yytext);
  return IF;
}

 /*
  * in
  */
[iI][nN] {
  stringtable.add_string(yytext);
  return IN;
}

 /*
  * inherits
  */
[iI][nN][hH][eE][rR][iI][tT][sS] {
  stringtable.add_string(yytext);
  return INHERITS;
}

 /*
  * isvoid
  */
[iI][sS][vV][oO][iI][dD] {
  stringtable.add_string(yytext);
  return ISVOID;
}

 /*
  * let
  */
[lL][eE][tT] {
  stringtable.add_string(yytext);
  return LET;
}

 /*
  * loop
  */
[lL][oO][oO][pP] {
  stringtable.add_string(yytext);
  return LOOP;
}

 /*
  * pool
  */
[pP][oO][oO][lL] {
  stringtable.add_string(yytext);
  return POOL;
}

 /*
  * then
  */
[tT][hH][eE][nN] {
  stringtable.add_string(yytext);
  return THEN;
}

 /*
  * while
  */
[wW][hH][iI][lL][eE] {
  stringtable.add_string(yytext);
  return WHILE;
}

 /*
  * case
  */
[cC][aA][sS][eE] {
  stringtable.add_string(yytext);
  return CASE;
}

 /*
  * esac
  */
[eE][sS][aA][cC] {
  stringtable.add_string(yytext);
  return ESAC;
}

 /*
  * of
  */
[oO][fF] {
  stringtable.add_string(yytext);
  return OF;
}

 /*
  * not
  */
[nN][oO][tT] {
  stringtable.add_string(yytext);
  return NOT;
}

 /*
  * new
  */
[nN][eE][wW] {
  stringtable.add_string(yytext);
  return NEW;
}

 /*
 * Identifiers
 */
{TYPE_ID} {
  cool_yylval.symbol = idtable.add_string(yytext);
  return TYPEID; 
}

{OBJECT_ID} {
  cool_yylval.symbol = idtable.add_string(yytext);
  return OBJECTID;
}

  /*
   * Integer
   */
{DIGIT}+ {
  cool_yylval.symbol = inttable.add_string(yytext);
  return INT_CONST;
}

{WHITESPACE} { /* Do nothing for whitespace */}

.	{
	cool_yylval.error_msg = strdup(yytext);
	return (ERROR); 
}


%%

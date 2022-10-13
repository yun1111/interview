grammar myCompiler;

options {
	language = Java;
}

@header {
    // import packages here.
    import java.util.HashMap;
    import java.util.ArrayList;
}

@members {
    boolean TRACEON = false;

    // Type information.
    public enum Type
    {
       ERR, BOOL, INT, FLOAT, CHAR, CONST_INT, CONST_FLOAT;
    }

    // This structure is used to record the information of a variable or a constant.
    class tVar 
    {
	   int   varIndex; // temporary variable's index. Ex: t1, t2, ..., etc.
	   int   iValue;   // value of constant integer. Ex: 123.
	   float fValue;   // value of constant floating point. Ex: 2.314.
	 };

    class Info
    {
       Type theType;  // type information.
       tVar theVar;
	   
	   Info()
      {
         theType = Type.ERR;
		   theVar = new tVar();
	   }
    };

	
    // ============================================
    // Create a symbol table.
	// ArrayList is easy to extend to add more info. into symbol table.
	//
	// The structure of symbol table:
	// <variable ID, [Type, [varIndex or iValue, or fValue]]>
	//    - type: the variable type   (please check "enum Type")
	//    - varIndex: the variable's index, ex: t1, t2, ...
	//    - iValue: value of integer constant.
	//    - fValue: value of floating-point constant.
    // ============================================

    HashMap<String, Info> symtab = new HashMap<String, Info>();

    // labelCount is used to represent temporary label.
    // The first index is 0.
    int labelCount = 0;  //L1.L2,...
	
    // varCount is used to represent temporary variables.
    // The first index is 0.
    int varCount = 0;   //t1,t2,...

    // Record all assembly instructions.
    List<String> TextCode = new ArrayList<String>();


    /*
     * Output prologue.
     */
    void prologue()   //when program start, initial action
    {
       TextCode.add("; === prologue ====");
       TextCode.add("declare dso_local i32 @printf(i8*, ...)\n");    //declare
       TextCode.add("@.str = private unnamed_addr constant [4 x i8] c\"\%d\\0A\\00\",align 1");
	   TextCode.add("define dso_local i32 @main()");
	   TextCode.add("{");
    }
    
	
    /*
     * Output epilogue.
     */

    void epilogue()  //when end of the program, some action
    {
       /* handle epilogue */
       TextCode.add("\n; === epilogue ===");
	   TextCode.add("ret i32 0");                       //return 
       TextCode.add("}");
    }
    
    
    /* Generate a new label */
    String newLabel()
    {
       labelCount ++;
       return (new String("L")) + Integer.toString(labelCount);
    } 
    
    
    public List<String> getTextCode()  //store all code we generate
    {
       return TextCode;
    }
}

program:
	VOID MAIN '(' ')' 
         {
           /* Output function prologue */
            prologue();
         } 
         '{' declarations statements '}'
         {
            if (TRACEON)
	         System.out.println("VOID MAIN () {declarations statements}");

           /* output function epilogue */	  
            epilogue();
        };

declarations:
	type Identifier ';' declarations
   {
           if (TRACEON)
              System.out.println("declarations: type Identifier : declarations");

           if (symtab.containsKey($Identifier.text))
           {
              // variable re-declared.
              System.out.println("Type Error: " + 
                                  $Identifier.getLine() + 
                                 ": Redeclared identifier.");
              System.exit(0);
           }
                 
           /* Add ID and its info into the symbol table. */
	      Info the_entry = new Info();
		   the_entry.theType = $type.attr_type;
		   the_entry.theVar.varIndex = varCount;
		   varCount ++;
		   symtab.put($Identifier.text, the_entry);

           // issue the instruction.
		   // Ex: \%a = alloca i32, align 4
           if ($type.attr_type == Type.INT)
           { 
              TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca i32, align 4");
           }
           // \%a = alloca float, align 4
           if ($type.attr_type == Type.FLOAT)
           { 
              TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca float, align 4");
           }
           // \%a = alloca i8, align 1
           if ($type.attr_type == Type.CHAR)
           { 
              TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca i8, align 1");
           }
   }
	| 
   {
           if (TRACEON)
              System.out.println("declarations: ");
   };

type
	returns[Type attr_type]:
	INT { if (TRACEON) System.out.println("type: INT"); $attr_type=Type.INT; }
	| CHAR { if (TRACEON) System.out.println("type: CHAR"); $attr_type=Type.CHAR; }
	| FLOAT {if (TRACEON) System.out.println("type: FLOAT"); $attr_type=Type.FLOAT; };

statements: statement statements |;

statement:
	assign_stmt ';'
	| if_stmt
	| func_no_return_stmt ';'
	| for_stmt;

func_no_return_stmt: Identifier '(' argument
{
   TextCode.add("call i32 (i8*,...) @" + $Identifier.text + "(" + $argument.str_arg + ") ");
}

 ')';

argument
returns[ String str_arg ]
:
 a = arg
 {
      if($a.theInfo.theType == Type.INT  )
         $str_arg = "i32 " + "\%t"+ $a.theInfo.theVar.varIndex;
      else if($a.theInfo.theType == Type.FLOAT )
         $str_arg = "float " + "\%t"+ $a.theInfo.theVar.varIndex;
      else 
         $str_arg = "i8* getelementptr inbounds ([" + $a.num + " x i8], [" + $a.num + " x i8]* @.str, i64 0, i64 0)";
 }
  (',' b = arg
  {
      if($b.theInfo.theType == Type.INT || $b.theInfo.theType == Type.FLOAT )
         $str_arg = $str_arg + " , " + "i32 " + "\%t"+$b.theInfo.theVar.varIndex;
      else if($a.theInfo.theType == Type.FLOAT )
         $str_arg = $str_arg + "float " + "\%t"+ $a.theInfo.theVar.varIndex;
  }
  )*;

arg
returns[Info theInfo , int num ]
@init {$theInfo = new Info(); $num = 0; }:
arith_expression 
{
   $theInfo = $arith_expression.theInfo;
}
| STRING_LITERAL
{ 
   $num = $STRING_LITERAL.text.length();
   $num = $num -2;
}
;

for_stmt:
	FOR '(' assign_stmt ';' 
   {
      TextCode.add("br label \%"+newLabel());
      TextCode.add("L"+labelCount+":");
      int start = labelCount;
   }
   cond_expression ';'
   {
      TextCode.add("br i1 \%t"+ $cond_expression.theInfo.theVar.varIndex +", label \%" + newLabel() + ", label \%" + newLabel() );
      int Tl = labelCount-1;
      int Fl = labelCount;
      TextCode.add(newLabel()+":");
      int next = labelCount;
   }
    assign_stmt 
    {
       TextCode.add("br label \%L"+start);
    }
    ')' 
    '{'
    {
      TextCode.add("L"+Tl+":");
    }
    statements 
    '}'
    {
       TextCode.add("br label \%L"+next);
       TextCode.add("L"+Fl+":");
    }
    ;

if_stmt: if_then_stmt if_else_stmt;

if_then_stmt: IF '(' cond_expression ')'
{
   //jump statement : br i1 a, label 1, label 2
   TextCode.add("br i1 \%t"+ $cond_expression.theInfo.theVar.varIndex +", label \%" + newLabel() + ", label \%" + newLabel() );
   labelCount--;
   TextCode.add("L"+labelCount+":");
   labelCount++;
}
block_stmt ;

if_else_stmt: ELSE 
{
   TextCode.add("br label \%"+newLabel());
   labelCount--;
   TextCode.add("L"+labelCount+":");
   labelCount++;
}
'{' statements'}'
{
   TextCode.add("L"+labelCount+":");
}

|
{
   TextCode.add("L"+labelCount+":");
}
;

block_stmt: '{' statements '}';

assign_stmt:
	Identifier '=' arith_expression
   {
            Info theRHS = $arith_expression.theInfo;
				Info theLHS = symtab.get($Identifier.text); 
		   
            if ((theLHS.theType == Type.INT) &&
               (theRHS.theType == Type.INT))
            {		   
                   // issue store insruction.
                   // Ex: store i32 \%tx, i32* \%ty
                   TextCode.add("store i32 \%t" + theRHS.theVar.varIndex + ", i32* \%t" + theLHS.theVar.varIndex + ", align 4");
				} 
            else if ((theLHS.theType == Type.INT) &&
				    (theRHS.theType == Type.CONST_INT))                  
            {
                   // issue store insruction.
                   // Ex: store i32 value, i32* \%ty
                   TextCode.add("store i32 " + theRHS.theVar.iValue + ", i32* \%t" + theLHS.theVar.varIndex + ", align 4");				
				}
            else if ((theLHS.theType == Type.FLOAT) &&
               (theRHS.theType == Type.FLOAT))
            {		
                   
                   TextCode.add("store float \%t" + theRHS.theVar.varIndex + ", float* \%t" + theLHS.theVar.varIndex + ", align 4");
				} 
            else if ((theLHS.theType == Type.FLOAT) &&
				    (theRHS.theType == Type.CONST_FLOAT))                
            {
                   long temp = Double.doubleToLongBits(theRHS.theVar.fValue );
                   TextCode.add("store float " + "0x" + Long.toHexString(temp) + ", float* \%t" + theLHS.theVar.varIndex + ", align 4");	
                  			
				}
	};



cond_expression
   returns[Info theInfo  ]
	@init {$theInfo = new Info(); }:
	a = arith_expression { $theInfo=$a.theInfo; }
   ( RelationOP b = arith_expression
   {
      int temp = $RelationOP.text.compareTo("<");
      if( 0 == temp)
      {
        if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.INT))
        {
         TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp slt i32 " + $a.theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
       else if(($a.theInfo.theType == Type.CONST_INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp slt i32 " + $a.theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
      }
      temp = $RelationOP.text.compareTo(">");
      if( 0 == temp)
      {
        if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sgt i32 " + $a.theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
       else if(($a.theInfo.theType == Type.CONST_INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sgt i32 " + $a.theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
      }
      temp = $RelationOP.text.compareTo("<=");
      if( 0 == temp)
      {
        if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sle i32 " + $a.theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
       else if(($a.theInfo.theType == Type.CONST_INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sle i32 " + $a.theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
      }
      temp = $RelationOP.text.compareTo(">=");
      if( 0 == temp)
      {
        if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sge i32 " + $a.theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
       else if(($a.theInfo.theType == Type.CONST_INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp sge i32 " + $a.theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
      }
      temp = $RelationOP.text.compareTo("==");
      if( 0 == temp)
      {
        if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.INT))
        {
         TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp eq i32 " + $a.theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
       else if(($a.theInfo.theType == Type.CONST_INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp eq i32 " + $a.theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
      }
      temp = $RelationOP.text.compareTo("!=");
      if( 0 == temp)
      {
        if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.INT))
        {
         TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
        else if(($a.theInfo.theType == Type.INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp ne i32 " + $a.theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
       else if(($a.theInfo.theType == Type.CONST_INT)&&($b.theInfo.theType == Type.CONST_INT))
        {
         TextCode.add("\%t" + varCount + " = icmp ne i32 " + $a.theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
         $theInfo.theType = Type.INT;
         $theInfo.theVar.varIndex = varCount ;
         varCount++;
        }
      }
   }
   )*;

arith_expression
	returns[Info theInfo]
	@init {theInfo = new Info(); }:
	a = multExpr { $theInfo=$a.theInfo; }
   (
		'+' b = multExpr {
                       // We need to do type checking first.
                       // ...
					  
                       // code generation.	
                       //a+b				   
                        if (($a.theInfo.theType == Type.INT) &&
                           ($b.theInfo.theType == Type.INT))
                        {
                           TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
					   
                           // Update arith_expression's theInfo.
                           $theInfo.theType = Type.INT;
                           $theInfo.theVar.varIndex = varCount;
                           varCount ++;
                        } 
                        //a+3
                        else if (($a.theInfo.theType == Type.INT) &&
					         ($b.theInfo.theType == Type.CONST_INT)) 
                        {
                           TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
					   
                           // Update arith_expression's theInfo.
                           $theInfo.theType = Type.INT;
                           $theInfo.theVar.varIndex = varCount;
                           varCount ++;
                        }
                        //2+a
                        else if (($a.theInfo.theType == Type.CONST_INT) &&
					         ($b.theInfo.theType == Type.INT)) 
                        {
                           TextCode.add("\%t" + varCount + " = add nsw i32 " + $theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
					   
                           // Update arith_expression's theInfo.
                           $theInfo.theType = Type.INT;
                           $theInfo.theVar.varIndex = varCount;
                           varCount ++;
                        }
                        //1+2
                        else if (($a.theInfo.theType == Type.CONST_INT) &&
					         ($b.theInfo.theType == Type.CONST_INT)) 
                        {
                           // Update arith_expression's theInfo.
                           $theInfo.theType = Type.CONST_INT;
                           $theInfo.theVar.iValue = $a.theInfo.theVar.iValue + $b.theInfo.theVar.iValue;
                        }
                        //a+b(float)
                        else if (($a.theInfo.theType == Type.FLOAT) &&
					         ($b.theInfo.theType == Type.FLOAT)) 
                        {
                           TextCode.add("\%t" + varCount + " = fadd float \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
					   
                           // Update arith_expression's theInfo.
                           $theInfo.theType = Type.FLOAT;
                           $theInfo.theVar.varIndex = varCount;
                           varCount ++;
                        }
                        //a+0.3
                        else if (($a.theInfo.theType == Type.FLOAT) &&
					         ($b.theInfo.theType == Type.CONST_FLOAT)) 
                        {
                           TextCode.add("\%t" + varCount + " = fpext float \%t" + $a.theInfo.theVar.varIndex + " to double");
                           $theInfo.theVar.varIndex = varCount;
                           varCount++;
                           TextCode.add("\%t" + varCount + " = fadd double \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.fValue);
                           // Update arith_expression's theInfo.
                           $theInfo.theType = Type.FLOAT;
                           $theInfo.theVar.varIndex = varCount;
                           varCount ++;
                           TextCode.add("\%t" + varCount + " = fptrunc double \%t" + $theInfo.theVar.varIndex + " to float");
                           $theInfo.theVar.varIndex = varCount;
                           varCount ++;
                        }
                        //0.2+a
                        else if (($a.theInfo.theType == Type.CONST_FLOAT) &&
					         ($b.theInfo.theType == Type.FLOAT)) 
                        {
                           TextCode.add("\%t" + varCount + " = fpext float \%t" + $b.theInfo.theVar.varIndex + " to double");
                           //$theInfo.theVar.varIndex = varCount;
                           varCount++;
                           TextCode.add("\%t" + varCount + " = fadd double " + $theInfo.theVar.fValue + ", \%t" + --varCount);
                           varCount++;
                           // Update arith_expression's theInfo.
                           $theInfo.theType = Type.FLOAT;
                           $theInfo.theVar.varIndex = varCount;
                           varCount ++;
                           TextCode.add("\%t" + varCount + " = fptrunc double \%t" + $theInfo.theVar.varIndex + " to float");
                           $theInfo.theVar.varIndex = varCount;
                           varCount ++;
                        }
                        //0.1+0.2
                        else if (($a.theInfo.theType == Type.CONST_FLOAT) &&
					         ($b.theInfo.theType == Type.CONST_FLOAT)) 
                        {
                           // Update arith_expression's theInfo.
                           $theInfo.theType = Type.CONST_FLOAT;
                           $theInfo.theVar.fValue = $a.theInfo.theVar.fValue + $b.theInfo.theVar.fValue;
                        }
                        
                    }
		| '-' c = multExpr      {
                              // We need to do type checking first.
                              // ...
                        
                              // code generation.	
                              //a+b				   
                                 if (($a.theInfo.theType == Type.INT) &&
                                    ($c.theInfo.theType == Type.INT))
                                 {
                                    TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.INT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 } 
                                 //a+3
                                 else if (($a.theInfo.theType == Type.INT) &&
                                 ($c.theInfo.theType == Type.CONST_INT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.INT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                              
                                 else if (($theInfo.theType == Type.CONST_INT) &&
                                 ($b.theInfo.theType == Type.INT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = sub nsw i32 " + $theInfo.theVar.iValue + ", \%t" + $c.theInfo.theVar.varIndex);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.INT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //1+2
                                 else if (($a.theInfo.theType == Type.CONST_INT) &&
                                 ($c.theInfo.theType == Type.CONST_INT)) 
                                 {
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.CONST_INT;
                                    $theInfo.theVar.iValue = $a.theInfo.theVar.iValue - $c.theInfo.theVar.iValue;
                                 }
                                 //a+b(float)
                                 else if (($a.theInfo.theType == Type.FLOAT) &&
                                 ($c.theInfo.theType == Type.FLOAT)) 
                                 {
                                    
                                    TextCode.add("\%t" + varCount + " = fsub float float \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.FLOAT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //a+0.3
                                 else if (($a.theInfo.theType == Type.FLOAT) &&
                                 ($c.theInfo.theType == Type.CONST_FLOAT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = fpext float \%t" + $a.theInfo.theVar.varIndex + " to double");
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount++;
                                    TextCode.add("\%t" + varCount + " = fsub double \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.fValue);
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.FLOAT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + $theInfo.theVar.varIndex + " to float");
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                    
                                 }
                                 //0.2+a
                                 else if (($a.theInfo.theType == Type.CONST_FLOAT) &&
                                 ($c.theInfo.theType == Type.FLOAT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = fpext float \%t" + $b.theInfo.theVar.varIndex + " to double");
                                    //$theInfo.theVar.varIndex = varCount;
                                    varCount++;
                                    TextCode.add("\%t" + varCount + " = fsub double " + $theInfo.theVar.fValue + ", \%t" + --varCount);
                                    varCount++;
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.FLOAT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + $theInfo.theVar.varIndex + " to float");
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //0.1+0.2
                                 else if (($a.theInfo.theType == Type.CONST_FLOAT) &&
                                 ($c.theInfo.theType == Type.CONST_FLOAT)) 
                                 {
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.CONST_FLOAT;
                                    $theInfo.theVar.fValue = $a.theInfo.theVar.fValue - $c.theInfo.theVar.fValue;
                                 }
                                 
                                 
                           }

	)*;

multExpr
	returns[Info theInfo]
	@init {theInfo = new Info();}:
	a = signExpr { $theInfo=$a.theInfo; } (   
		'*' b = signExpr            {
                              // We need to do type checking first.
                              // ...
                        
                              // code generation.	
                              //a*b				   
                                 if (($a.theInfo.theType == Type.INT) &&
                                    ($b.theInfo.theType == Type.INT))
                                 {
                                    TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.INT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 } 
                                 //a+3
                                 else if (($a.theInfo.theType == Type.INT) &&
                                 ($b.theInfo.theType == Type.CONST_INT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.INT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //2+a
                                 else if (($a.theInfo.theType == Type.CONST_INT) &&
                                 ($b.theInfo.theType == Type.INT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = mul nsw i32 " + $theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.INT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //1+2
                                 else if (($a.theInfo.theType == Type.CONST_INT) &&
                                 ($b.theInfo.theType == Type.CONST_INT)) 
                                 {
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.CONST_INT;
                                    $theInfo.theVar.iValue = $a.theInfo.theVar.iValue * $b.theInfo.theVar.iValue;
                                 }
                                 //a+b(float)
                                 else if (($a.theInfo.theType == Type.FLOAT) &&
                                 ($b.theInfo.theType == Type.FLOAT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = fmul float \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.FLOAT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //a+0.3
                                 else if (($a.theInfo.theType == Type.FLOAT) &&
                                 ($b.theInfo.theType == Type.CONST_FLOAT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = fpext float \%t" + $a.theInfo.theVar.varIndex + " to double");
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount++;
                                    TextCode.add("\%t" + varCount + " = fmul double \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.fValue);
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.FLOAT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + $theInfo.theVar.varIndex + " to float");
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //0.2+a
                                 else if (($a.theInfo.theType == Type.CONST_FLOAT) &&
                                 ($b.theInfo.theType == Type.FLOAT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = fpext float \%t" + $b.theInfo.theVar.varIndex + " to double");
                                    //$theInfo.theVar.varIndex = varCount;
                                    varCount++;
                                    TextCode.add("\%t" + varCount + " = fmul double " + $theInfo.theVar.fValue + ", \%t" + --varCount);
                                    varCount++;
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.FLOAT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + $theInfo.theVar.varIndex + " to float");
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //0.1+0.2
                                 else if (($a.theInfo.theType == Type.CONST_FLOAT) &&
                                 ($b.theInfo.theType == Type.CONST_FLOAT)) 
                                 {
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.CONST_FLOAT;
                                    $theInfo.theVar.fValue = $a.theInfo.theVar.fValue * $b.theInfo.theVar.fValue;
                                 }
                                 
                           }
		| '/' c = signExpr       {
                              // We need to do type checking first.
                              // ...
                        
                              // code generation.	
                              //a*b				   
                                 if (($a.theInfo.theType == Type.INT) &&
                                    ($c.theInfo.theType == Type.INT))
                                 {
                                    TextCode.add("\%t" + varCount + " = div i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.INT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 } 
                                 //a+3
                                 else if (($a.theInfo.theType == Type.INT) &&
                                 ($c.theInfo.theType == Type.CONST_INT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = div i32 \%t" + $theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.INT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //2+a
                                 else if (($a.theInfo.theType == Type.CONST_INT) &&
                                 ($b.theInfo.theType == Type.INT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = div i32 \%t" + $theInfo.theVar.iValue + ", " + $c.theInfo.theVar.varIndex);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.INT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //1+2
                                 else if (($a.theInfo.theType == Type.CONST_INT) &&
                                 ($c.theInfo.theType == Type.CONST_INT)) 
                                 {
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.CONST_INT;
                                    $theInfo.theVar.iValue = $a.theInfo.theVar.iValue / $c.theInfo.theVar.iValue;
                                 }
                                 //a+b(float)
                                 else if (($a.theInfo.theType == Type.FLOAT) &&
                                 ($c.theInfo.theType == Type.FLOAT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = fdiv float \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
                           
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.FLOAT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 //a+0.3
                                 else if (($a.theInfo.theType == Type.FLOAT) &&
                                 ($c.theInfo.theType == Type.CONST_FLOAT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = fpext float \%t" + $a.theInfo.theVar.varIndex + " to double");
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount++;
                                    TextCode.add("\%t" + varCount + " = fdiv double \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.fValue);
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.FLOAT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + $theInfo.theVar.varIndex + " to float");
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 else if (($a.theInfo.theType == Type.CONST_FLOAT) &&
                                 ($c.theInfo.theType == Type.FLOAT)) 
                                 {
                                    TextCode.add("\%t" + varCount + " = fpext float \%t" + $b.theInfo.theVar.varIndex + " to double");
                                    //$theInfo.theVar.varIndex = varCount;
                                    varCount++;
                                    TextCode.add("\%t" + varCount + " = fdiv double " + $theInfo.theVar.fValue + ", \%t" + --varCount);
                                    varCount++;
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = Type.FLOAT;
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                    TextCode.add("\%t" + varCount + " = fptrunc double \%t" + $theInfo.theVar.varIndex + " to float");
                                    $theInfo.theVar.varIndex = varCount;
                                    varCount ++;
                                 }
                                 /*//0.1+0.2
                                 else if (($a.theInfo.theType == Type.CONST_FLOAT) &&
                                 ($c.theInfo.theType == Type.CONST_FLOAT)) 
                                 {
                                    // Update arith_expression's theInfo.
                                    $theInfo.theType = TypeCONST_FLOAT;
                                    $theInfo.theVar.fValue = $a.theInfo.theVar.fValue / $c.theInfo.theVar.fValue;
                                 }*/
                                 
                           }
	)*;

signExpr
	returns[Info theInfo]
	@init {theInfo = new Info();}: 
   a = primaryExpr { $theInfo=$a.theInfo; }                
   | '-'  b = primaryExpr   {

                                 $theInfo=$b.theInfo;
                                 if($b.theInfo.theType == Type.INT)
                                 {
                                    TextCode.add("\%t" + varCount + " = sub nsw i32 0, \%t" + $b.theInfo.theVar.varIndex );
                                    $b.theInfo.theVar.varIndex = varCount;
                                    varCount++;
                                 }
                                 else if($b.theInfo.theType == Type.FLOAT)
                                 {
                                    TextCode.add("\%t" + varCount + " = sub nsw float 0, \%t" + $b.theInfo.theVar.varIndex );
                                    $b.theInfo.theVar.varIndex = varCount;
                                    varCount++;
                                 }
                              }
   ;

primaryExpr
	returns[Info theInfo]
	@init {theInfo = new Info();}:
	Integer_constant  {
                        $theInfo.theType = Type.CONST_INT;
                        $theInfo.theVar.iValue = Integer.parseInt($Integer_constant.text);
                     }
	| Floating_point_constant  {
                                 $theInfo.theType = Type.CONST_FLOAT;
                                  $theInfo.theVar.fValue =  Float.parseFloat($Floating_point_constant.text);
                              }
   | Identifier   {
                     // get type information from symtab.
                     Type the_type = symtab.get($Identifier.text).theType;
                     $theInfo.theType = the_type;

                     // get variable index from symtab.
                     int vIndex = symtab.get($Identifier.text).theVar.varIndex;
                     
                     switch (the_type)
                     {
                        case INT: 
                              // get a new temporary variable and
                              // load the variable into the temporary variable.
                                    
                              // Ex: \%tx = load i32, i32* \%ty.
                              TextCode.add("\%t" + varCount + " = load i32, i32* \%t" + vIndex + ", align 4");
                              // Now, Identifier's value is at the temporary variable \%t[varCount].
                              // Therefore, update it.
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                               

                              

                              break;
                        case FLOAT:
                              TextCode.add("\%t" + varCount + " = load float, float* \%t" + vIndex + ", align 4");
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                              
                              break;
                        case CHAR:
                              TextCode.add("\%t" + varCount + " = load i8, i8* \%t" + vIndex + ", align 4");
                              $theInfo.theVar.varIndex = varCount;
                              varCount ++;
                              break;
                  
                     }
                  }
	//| '&' Identifier                  ///////////////////////////////////////////////???????????????????????????????????
	| '(' arith_expression ')'    {
                                    $theInfo = $arith_expression.theInfo;
                                 }
   ;

/* description of the tokens */
FLOAT: 'float';
INT: 'int';
CHAR: 'char';

MAIN: 'main';
VOID: 'void';
IF: 'if';
ELSE: 'else';
FOR: 'for';

RelationOP: '>' | '>=' | '<' | '<=' | '==' | '!=';

Identifier: ('a' ..'z' | 'A' ..'Z' | '_') (
		'a' ..'z'
		| 'A' ..'Z'
		| '0' ..'9'
		| '_'
	)*;
Integer_constant: '0' ..'9'+;
Floating_point_constant: '0' ..'9'+ '.' '0' ..'9'+;

STRING_LITERAL: '"' ( EscapeSequence | ~('\\' | '"'))* '"';

WS: ( ' ' | '\t' | '\r' | '\n') {$channel=HIDDEN;};
COMMENT1:'/*' .* '*/' {$channel=HIDDEN;};
COMMENT2: '//'(.)*'\n'{$channel=HIDDEN;};

fragment EscapeSequence:
	'\\' ('b' | 't' | 'n' | 'f' | 'r' | '\"' | '\'' | '\\');



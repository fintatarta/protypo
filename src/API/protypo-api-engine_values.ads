pragma Ada_2012;
with Ada.Containers.Indefinite_Vectors;
limited with Protypo.Api.Engine_Values.Handlers;

package Protypo.Api.Engine_Values is
   use Ada.Strings.Unbounded;

   type Engine_Value_Class is
     (
      Void,
      Int,
      Real,
      Text,
      Array_Handler,
      Ambivalent_Handler,
      Record_Handler,
      Function_Handler,
      Constant_Handler,
      Iterator
     );

   subtype Scalar_Classes  is Engine_Value_Class range Int .. Text;
   subtype Numeric_Classes is Scalar_Classes     range Int .. Real;
   subtype Handler_Classes is Engine_Value_Class range Array_Handler .. Constant_Handler;

   subtype Indexed_Handler is Engine_Value_Class
     with
       Static_Predicate => Indexed_Handler in Array_Handler | Ambivalent_Handler;

   subtype Record_Like_Handler is Engine_Value_Class
     with
       Static_Predicate => Record_Like_Handler in Record_Handler | Ambivalent_Handler;


   type Engine_Value (Class : Engine_Value_Class) is private;

   Void_Value     : constant Engine_Value;

   subtype Integer_Value    is Engine_Value (Int);
   subtype Real_Value       is Engine_Value (Real);
   subtype String_Value     is Engine_Value (Text);
   subtype Array_Value      is Engine_Value (Array_Handler);
   subtype Record_Value     is Engine_Value (Record_Handler);
   subtype Ambivalent_Value is Engine_Value (Ambivalent_Handler);
   subtype Iterator_Value   is Engine_Value (Iterator);
   subtype Function_Value   is Engine_Value (Function_Handler);
   subtype Constant_Value   is Engine_Value (Constant_Handler);

   subtype Handler_Value is Engine_Value
     with Dynamic_Predicate =>
       (Handler_Value.Class in Array_Handler .. Constant_Handler);

   --
   --  Arrays of engine values. Used in many places like indexing of
   --  arrays or function calls.
   --

   type Engine_Value_Array is tagged private;

   subtype Engine_Index is Positive;

   subtype Extended_Index is Engine_Index'Base
   range Engine_Index'First - 1 ..
     Engine_Index'Min (Engine_Index'Base'Last - 1, Engine_Index'Last) + 1;

   No_Index : constant Extended_Index := Extended_Index'First;


   function Element  (V     : Engine_Value_Array;
                      Index : Engine_Index)
                      return Engine_Value;

   function First_Index (V : Engine_Value_Array) return Engine_Index;

   function Last_Index (V : Engine_Value_Array) return Extended_Index;

   function Length (V : Engine_Value_Array) return Natural
   is (if V.Last_Index < V.First_Index then
          0
       else
          V.Last_Index - V.First_Index + 1);

   procedure Append (V    : in out Engine_Index;
                     Item : Engine_Value);

   function Singleton (Item : Engine_Value)
                       return Engine_Value_Array
     with
       Post =>
         Singleton'Result.First_Index = Engine_Index'First
         and Singleton'Result.Last_Index = Engine_Index'First;

   --
   --  A reference is a kind of "pointer" to an Engine_Value.
   --  It can be used to get the value "pointed to" or to update it,
   --  if the reference is a Writable_Reference.
   --
   --  Array, records and ambivalent interfaces always return
   --  references.  This allows to update (if the reference is
   --  writable) the content of the array, ...
   --
   type Reference is interface;

   type Reference_Access is access all Reference;

   function Read (Ref : Reference) return Engine_Value
                  is abstract;

   type Writable_Reference is interface and Reference;

   procedure Write (Ref       : Writable_Reference;
                    New_Value : Engine_Value)
   is abstract;



   function Is_Scalar (X : Engine_Value) return Boolean
   is (X.Class in Scalar_Classes);


   function Is_Numeric (X : Engine_Value) return Boolean
   is (X.Class in Numeric_Classes);

   function Is_Handler (X : Engine_Value) return Boolean
   is (X.Class in Handler_Classes);

   function Mixed_Numeric (X, Y : Numeric_Classes) return Numeric_Classes
   is (if X = Y then X else Real);
   -- Function used in contracts.  Return the highest common numeric
   -- class between X and Y (Int if both are integers, Real otherwise)

   function Compatible_Scalars (X, Y : Engine_Value) return Boolean
   is ((X.Class = Text and Y.Class = Text) or (Is_Numeric (X) and Is_Numeric (Y)))
     with Pre => Is_Scalar (X) and Is_Scalar (Y);
   -- Function used in contract to express the fact that X and Y are
   -- compatible, that is, they are both text or numeric.

   function Identity (X : Engine_Value) return Engine_Value
   is (X);
   -- Strange this function, uh?  Well, it is convenient to instantiate
   -- generic wrapper packages. See, for example, Array_Wrappers

   function "-" (X : Engine_Value) return Engine_Value
     with Pre => Is_Numeric (X),
     Post => X.Class = "-"'Result.Class;

   function "not" (X : Engine_Value) return Integer_Value
     with Pre => Is_Numeric (X);

   function "mod" (X, Y : Integer_Value) return Integer_Value;

   function "+" (Left, Right : Engine_Value) return Engine_Value
     with
       Pre =>
         (Left.Class = Text and Right.Class = Text)
         or (Is_Numeric (Left) and Is_Numeric (Right)),
         Post =>
           "+"'Result.Class = (if Is_Numeric (Left)
                                 then
                                   Mixed_Numeric (Left.Class, Right.Class)
                                 else
                                   Text);

   function "-" (Left, Right : Engine_Value) return Engine_Value
     with Pre => Is_Numeric (Left) and Is_Numeric (Right),
     Post => "-"'Result.Class = Mixed_Numeric (Left.Class, Right.Class);

   function "*" (Left, Right : Engine_Value) return Engine_Value
     with Pre => Is_Numeric (Left) and Is_Numeric (Right),
     Post => "*"'Result.Class = Mixed_Numeric (Left.Class, Right.Class);

   function "/" (Left, Right : Engine_Value) return Engine_Value
     with Pre => Is_Numeric (Left) and Is_Numeric (Right),
     Post => "/"'Result.Class = Mixed_Numeric (Left.Class, Right.Class);


   function "=" (Left, Right : Engine_Value) return Integer_Value
     with Pre => Compatible_Scalars (Left, Right);

   function "/=" (Left, Right : Engine_Value) return Integer_Value
     with Pre => Compatible_Scalars (Left, Right);

   function "<" (Left, Right : Engine_Value) return Integer_Value
     with Pre => Compatible_Scalars (Left, Right);

   function "<=" (Left, Right : Engine_Value) return Integer_Value
     with Pre => Compatible_Scalars (Left, Right);

   function ">" (Left, Right : Engine_Value) return Integer_Value
     with Pre => Compatible_Scalars (Left, Right);

   function ">=" (Left, Right : Engine_Value) return Integer_Value
     with Pre => Compatible_Scalars (Left, Right);

   function "and" (Left, Right : Integer_Value) return Integer_Value;
   function "or"  (Left, Right : Integer_Value) return Integer_Value;
   function "xor" (Left, Right : Integer_Value) return Integer_Value;



   function Create (Val : Integer) return Integer_Value;

   function Create (Val : Float) return Real_Value;

   function Create (Val : String) return String_Value;

   function Create (Val : Unbounded_String) return String_Value;

   function Create (Val : Boolean) return Integer_Value;

   function Get_Integer (Val : Integer_Value) return Integer;
   function Get_Integer (Val : Engine_Value; Default : Integer) return Integer;

   function Get_Boolean (Val : Integer_Value) return Boolean;

   function Get_Float (Val : Real_Value) return Float;
   function Get_Float (Val : Engine_Value; Default : Float) return Float;

   function Get_String (Val : String_Value) return String;
   function Get_String (Val : Engine_Value; Default : String) return String;

   function Get_Field (Val   : Engine_Value;
                       Field : Id)
                       return Reference'Class
     with
       Pre =>
         Val.Class in Record_Like_Handler;

   function Get_Indexed (Val   : Engine_Value;
                         Index : Engine_Value_Array)
                         return Reference'Class
     with
       Pre =>
         Val.Class in Indexed_Handler;
private
   --     type Engine_Value_Vector is range 1 .. 2;

   type Engine_Value (Class : Engine_Value_Class) is
      record
         case Class is
            when Void =>
               null;

            when Int =>
               Int_Val : Integer;

            when Real =>
               Real_Val : Float;

            when Text =>
               Text_Val : Unbounded_String;

            when Array_Handler =>
               Array_Object : access Handlers.Array_Interface;

            when Record_Handler =>
               Record_Object : access Handlers.Record_Interface;

            when Ambivalent_Handler =>
               Ambivalent_Object : access Handlers.Ambivalent_Interface;

            when Iterator =>
               Iteration_Object : access Handlers.Iterator_Interface;

            when Function_Handler =>
               Function_Object : access Handlers.Function_Interface;

               --  when Reference_Handler =>
               --     Reference_Object : access Handlers.Reference_Interface;

            when Constant_Handler =>
               Constant_Object  : access Handlers.Constant_Interface;
         end case;
      end record;

   Void_Value     : constant Engine_Value := (Class => Void);


   package Engine_Value_Arrays is
     new Ada.Containers.Indefinite_Vectors (Index_Type   => Engine_Index,
                                            Element_Type => Engine_Value);

   type Engine_Value_Array is new Engine_Value_Arrays.Vector with null record;

   function Bool (X : Integer) return Integer
   is (if X /= 0 then 1 else 0);

   function Bool (X : Float) return Integer
   is (if X /= 0.0 then 1 else 0);


   function Bool (X : Engine_Value) return Integer
   is (case X.Class is
          when Int    => Bool (Get_Integer (X)),
          when Real   => Bool (Get_Float (X)),
          when others => raise Constraint_Error);

   function Real (X : Engine_Value) return Float
   is (case X.Class is
          when Int    => Float (Get_Integer (X)),
          when Real   => Get_Float (X),
          when others => raise Constraint_Error);


   function Create (Val : Integer) return Integer_Value
   is (Engine_Value'(Class            => Int,
                     Int_Val          => Val));


   function Create (Val : Float) return Real_Value
   is (Engine_Value'(Class            => Real,
                     Real_Val         => Val));

   function Create (Val : String) return String_Value
   is (Engine_Value'(Class            => Text,
                     Text_Val         => To_Unbounded_String (Val)));

   function Create (Val : Unbounded_String) return String_Value
   is (Create (To_String (Val)));

   function Create (Val : Boolean) return Integer_Value
   is (Engine_Value'(Class            => Int,
                     Int_Val          => (if Val then 1 else 0)));


   function Get_Integer (Val : Integer_Value) return Integer
   is (Val.Int_Val);

   function Get_Integer (Val : Engine_Value; Default : Integer) return Integer
   is (case Val.Class is
          when Void   =>
             Default,

          when Int    =>
             Val.Int_Val,

          when others =>
             raise Constraint_Error);

   function Get_Float (Val : Real_Value) return Float
   is (Val.Real_Val);

   function Get_Float (Val : Engine_Value; Default : Float) return Float
   is (case Val.Class is
          when Void   =>
             Default,

          when Int    =>
             Float (Val.Int_Val),

          when Real   =>
             Val.Real_Val,

          when others =>
             raise Constraint_Error);

   function Get_String (Val : String_Value) return String
   is (To_String (Val.Text_Val));

   function Get_String (Val : Engine_Value; Default : String) return String
   is (case Val.Class is
          when Void    =>
             Default,

          when Text    =>
             Get_String (Val),

          when others  =>
             raise Constraint_Error);


   function Get_Boolean (Val : Integer_Value) return Boolean
   is ((if Val.Int_Val = 0 then False else True));


   function "-" (Left, Right : Engine_Value) return Engine_Value
   is (Left + (-Right));

   function "/=" (Left, Right : Engine_Value) return Integer_Value
   is (not (Left = Right));

   function ">" (Left, Right : Engine_Value) return Integer_Value
   is (Right < Left);

   function "<=" (Left, Right : Engine_Value) return Integer_Value
   is (Right >= Left);

   function ">=" (Left, Right : Engine_Value) return Integer_Value
   is (not (Left < Right));



end Protypo.Api.Engine_Values;

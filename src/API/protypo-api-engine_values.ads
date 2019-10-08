package Protypo.API.Engine_Values is
   use Ada.Strings.Unbounded;

   type Engine_Value_Class is
     (
      Void,
      Int,
      Real,
      Text,
      Array_Handler,
      Record_Handler,
      Ambivalent_Handler,
      Function_Handler,
      Reference_Handler,
      Constant_Handler,
      Iterator
     );

   subtype Scalar_Classes  is Engine_Value_Class  range Int .. Text;
   subtype Numeric_Classes is Scalar_Classes     range Int .. Real;
   subtype Handler_Classes is Engine_Value_Class range Array_Handler .. Constant_Handler;

   type Engine_Value (Class : Engine_Value_Class := Void) is private;

   Void_Value     : constant Engine_Value;

   subtype Integer_Value    is Engine_Value (Int);
   subtype Real_Value       is Engine_Value (Real);
   subtype String_Value     is Engine_Value (Text);
   subtype Array_Value      is Engine_Value (Array_Handler);
   subtype Record_Value     is Engine_Value (Record_Handler);
   subtype Ambivalent_Value is Engine_Value (Ambivalent_Handler);
   subtype Iterator_Value   is Engine_Value (Iterator);
   subtype Function_Value   is Engine_Value (Function_Handler);
   subtype Reference_Value  is Engine_Value (Reference_Handler);
   subtype Constant_Value   is Engine_Value (Constant_Handler);

   subtype Handler_Value is Engine_Value
     with Dynamic_Predicate => Handler_Value.Class in Handler_Classes;


   type Engine_Value_Array is array (Positive range <>) of Engine_Value;

   No_Value   : constant Engine_Value_Array;


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

   function "-" (X : Engine_Value) return Engine_Value
     with Pre => Is_Numeric (X),
     Post => X.Class = "-"'Result.Class;

   function "not" (X : Engine_Value) return Engine_Value
     with Pre => Is_Numeric (X),
     Post => "not"'Result.Class = Int;


   function "+" (Left, Right : Engine_Value) return Engine_Value
     with Pre => (Left.Class = Text and Right.Class = Text)
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


   function "=" (Left, Right : Engine_Value) return Engine_Value
     with Pre => Compatible_Scalars (Left, Right),
     Post => "="'Result.Class = Int;

   function "/=" (Left, Right : Engine_Value) return Engine_Value
     with Pre => Compatible_Scalars (Left, Right),
     Post => "/="'Result.Class = Int;

   function "<" (Left, Right : Engine_Value) return Engine_Value
     with Pre => Compatible_Scalars (Left, Right),
     Post => "<"'Result.Class = Int;
   function "<=" (Left, Right : Engine_Value) return Engine_Value
     with Pre => Compatible_Scalars (Left, Right),
     Post => "<="'Result.Class = Int;

   function ">" (Left, Right : Engine_Value) return Engine_Value
     with Pre => Compatible_Scalars (Left, Right),
     Post => ">"'Result.Class = Int;

   function ">=" (Left, Right : Engine_Value) return Engine_Value
     with Pre => Compatible_Scalars (Left, Right),
     Post => ">="'Result.Class = Int;

   function "and" (Left, Right : Engine_Value) return Engine_Value;
   function "or"  (Left, Right : Engine_Value) return Engine_Value;
   function "xor" (Left, Right : Engine_Value) return Engine_Value;


   type Array_Interface is interface;
   type Array_Interface_Access is access all Array_Interface'Class;

   function Get (X     : Array_Interface;
                 Index : Engine_Value_Array)
                 return Handler_Value
                 is abstract
     with Post'Class => Get'Result.Class in Handler_Classes;


   Out_Of_Range : exception;

   type Record_Interface is interface;
   type Record_Interface_Access is access all Record_Interface'Class;

   function Is_Field (X : Record_Interface; Field : ID) return Boolean
                      is abstract;

   function Get (X     : Record_Interface;
                 Field : ID)
                 return Handler_Value
                 is abstract
     with Post'Class => Get'Result.Class in Handler_Classes;

   Unknown_Field : exception;

   type Ambivalent_Interface is interface
     and Record_Interface
     and Array_Interface;

   type Ambivalent_Interface_Access is  access all Ambivalent_Interface'Class;

   type Constant_Interface is interface;
   type Constant_Interface_Access  is  access all Constant_Interface'Class;

   function Read (X : Constant_Interface) return Engine_Value is abstract;

   type Reference_Interface is interface and Constant_Interface;
   type Reference_Interface_Access is access all Reference_Interface'Class;

   procedure Write (What  : Reference_Interface;
                    Value : Engine_Value)
   is abstract;

   --     procedure Set (X     : in out Array_Interface;
   --                    Field : String;
   --                    Value : Engine_Value)
   --     is abstract;

   type Iterator_Interface is limited interface;
   type Iterator_Interface_Access is access all Iterator_Interface'Class;


   procedure Reset (Iter : in out Iterator_Interface) is abstract;
   procedure Next (Iter : in out Iterator_Interface) is abstract
     with Pre'Class => not Iter.End_Of_Iteration;

   function End_Of_Iteration (Iter : Iterator_Interface)
                              return Boolean is abstract;

   function Element (Iter : Iterator_Interface)
                     return Handler_Value is abstract
     with Pre'Class => not Iter.End_Of_Iteration;

   type Function_Interface is interface;
   type Function_Interface_Access is access all Function_Interface'Class;

   function Process (Fun       : Function_Interface;
                     Parameter : Engine_Value_Array)
                     return Engine_Value_Array is abstract;

   type Parameter_Class is (Mandatory, Optional, Varargin);

   type Parameter_Spec (Class : Parameter_Class := Mandatory) is
      record
         case Class is
            when Mandatory | Varargin =>
               null;

            when Optional =>
               Default : Engine_Value;
         end case;
      end record;

   type Parameter_Signature is array (Positive range <>) of Parameter_Spec;

   function Is_Valid_Parameter_Signature (Signature : Parameter_Signature) return Boolean;

   --
   -- Return True if Signature is a valid parameter signature that can be returned
   -- by Signature method.  A valid signature satisfies the following "regexp"
   --
   --   Void_Value* Non_Void_Value* Varargin_Value?
   --
   -- that is,
   -- * there is a "head" (potentially empty) of void values that
   -- mark the parameters that are mandatory and have no default;
   --
   -- * a (maybe empty) sequence of non void values follows, these are
   -- default values of optional parameters
   --
   -- * the last entry can be Varargin_Value, showing that the
   -- last parameter is an array (maybe empty) that collects all the
   -- remaining parameters
   --
   function Signature (Fun : Function_Interface)
                                return Parameter_Signature is abstract
     with Post'Class => Is_Valid_Parameter_Signature (Signature'Result);

   type Callback_Function_Access is
   not null access function (Parameters : Engine_Value_Array) return Engine_Value_Array;


   function Create (Val : Integer) return Engine_Value
     with Post => Create'Result.Class = Int;

   function Create (Val : Float) return Engine_Value
     with Post => Create'Result.Class = Real;

   function Create (Val : String) return Engine_Value
     with Post => Create'Result.Class = Text;

   function Create (Val : Array_Interface_Access) return Engine_Value
     with Post => Create'Result.Class = Array_Handler;

   function Create (Val : Record_Interface_Access) return Engine_Value
     with Post => Create'Result.Class = Record_Handler;

   function Create (Val : Ambivalent_Interface_Access) return Engine_Value
     with Post => Create'Result.Class = Ambivalent_Handler;

   function Create (Val : Iterator_Interface_Access) return Engine_Value
     with Post => Create'Result.Class = Iterator;

   function Create (Val : Function_Interface_Access) return Engine_Value
     with Post => Create'Result.Class = Function_Handler;

   function Create (Val          : Callback_Function_Access;
                    N_Parameters : Natural := 1) return Engine_Value
     with Post => Create'Result.Class = Function_Handler;

   function Create (Val : Reference_Interface_Access) return Engine_Value
     with Post => Create'Result.Class = Reference_Handler;

   function Create (Val : Constant_Interface_Access) return Engine_Value
     with Post => Create'Result.Class = Constant_Handler;


   function Get_Integer (Val : Integer_Value) return Integer;
   function Get_Float (Val : Real_Value) return Float;
   function Get_String (Val : String_Value) return String;
   function Get_Array (Val : Array_Value) return Array_Interface_Access;
   function Get_Record (Val : Record_Value) return Record_Interface_Access;
   function Get_Ambivalent (Val : Ambivalent_Value) return Ambivalent_Interface_Access;
   function Get_Iterator (Val : Iterator_Value) return Iterator_Interface_Access;
   function Get_Function (Val : Function_Value) return Function_Interface_Access;
   function Get_Reference (Val : Reference_Value) return Reference_Interface_Access;
   function Get_Constant (Val : Constant_Value) return Constant_Interface_Access;

private
   --     type Engine_Value_Vector is range 1 .. 2;

   type Engine_Value (Class : Engine_Value_Class := Void) is
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
            Array_Object : Array_Interface_Access;

         when Record_Handler =>
            Record_Object : Record_Interface_Access;

         when Ambivalent_Handler =>
            Ambivalent_Object : Ambivalent_Interface_Access;

         when Iterator =>
            Iteration_Object : Iterator_Interface_Access;

         when Function_Handler =>
            Function_Object : Function_Interface_Access;

         when Reference_Handler =>
            Reference_Object : Reference_Interface_Access;

         when Constant_Handler =>
            Constant_Object  : Constant_Interface_Access;
         end case;
      end record;

   Void_Value     : constant Engine_Value := (Class => Void);
   No_Value       : constant Engine_Value_Array (2 .. 1) := (others => Void_Value);

   type Callback_Based_Handler is
     new Function_Interface
   with
      record
         Callback     : Callback_Function_Access;
         N_Parameters : Natural;
      end record;

   function Process (Fun       : Callback_Based_Handler;
                     Parameter : Engine_Value_Array)
                     return Engine_Value_Array
   is (Fun.Callback (Parameter));

   function Signature (Fun : Callback_Based_Handler)
                                return Parameter_Signature;
   --     is (Engine_Value_Array(2..Fun.N_Parameters+1)'(others => Void_Value));


   function Create (Val : Integer) return Engine_Value
   is (Engine_Value'(Class            => Int,
                     Int_Val          => Val));


   function Create (Val : Float) return Engine_Value
   is (Engine_Value'(Class            => Real,
                     Real_Val         => Val));

   function Create (Val : String) return Engine_Value
   is (Engine_Value'(Class            => Text,
                     Text_Val         => To_Unbounded_String (Val)));

   function Create (Val : Array_Interface_Access) return Engine_Value
   is (Engine_Value'(Class            => Array_Handler,
                     Array_Object     => Val));

   function Create (Val : Record_Interface_Access) return Engine_Value
   is (Engine_Value'(Class            => Record_Handler,
                     Record_Object    => Val));

   function Create (Val : Ambivalent_Interface_Access) return Engine_Value
   is (Engine_Value'(Class             => Ambivalent_Handler,
                     Ambivalent_Object => Val));


   function Create (Val : Iterator_Interface_Access) return Engine_Value
   is (Engine_Value'(Class            => Iterator,
                     Iteration_Object => Val));

   function Create (Val : Function_Interface_Access) return Engine_Value
   is (Engine_Value'(Class            => Function_Handler,
                     Function_Object  => Val));

   function Create (Val          : Callback_Function_Access;
                    N_Parameters : Natural := 1)
                    return Engine_Value
   is (Create (new Callback_Based_Handler'(Callback => Val,
                                           N_Parameters => N_Parameters)));

   function Create (Val : Reference_Interface_Access) return Engine_Value
   is (Engine_Value'(Class            => Reference_Handler,
                     Reference_Object => Val));

   function Create (Val : Constant_Interface_Access) return Engine_Value
   is (Engine_Value'(Class            => Constant_Handler,
                     Constant_Object  => Val));

   function Get_Integer (Val : Integer_Value) return Integer
   is (Val.Int_Val);

   function Get_Float (Val : Real_Value) return Float
   is (Val.Real_Val);

   function Get_String (Val : String_Value) return String
   is (To_String (Val.Text_Val));

   function Get_Array (Val : Array_Value) return Array_Interface_Access
   is (Val.Array_Object);

   function Get_Record (Val : Record_Value) return Record_Interface_Access
   is (Val.Record_Object);

   function Get_Ambivalent (Val : Ambivalent_Value) return Ambivalent_Interface_Access
   is (Val.Ambivalent_Object);

   function Get_Iterator (Val : Iterator_Value) return Iterator_Interface_Access
   is (Val.Iteration_Object);

   function Get_Function (Val : Function_Value) return Function_Interface_Access
   is (Val.Function_Object);

   function Get_Reference (Val : Reference_Value) return Reference_Interface_Access
   is (Val.Reference_Object);

   function Get_Constant (Val : Constant_Value) return Constant_Interface_Access
   is (Val.Constant_Object);


   function "-" (Left, Right : Engine_Value) return Engine_Value
   is (Left + (-Right));

   function "/=" (Left, Right : Engine_Value) return Engine_Value
   is (not (Left = Right));

   function ">" (Left, Right : Engine_Value) return Engine_Value
   is (Right < Left);

   function "<=" (Left, Right : Engine_Value) return Engine_Value
   is (Right >= Left);

   function ">=" (Left, Right : Engine_Value) return Engine_Value
   is (not (Left < Right));

end Protypo.API.Engine_Values;

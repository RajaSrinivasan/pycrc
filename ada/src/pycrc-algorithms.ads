--  pycrc -- parameterisable CRC calculation utility and Ada source generator.
--
--  Copyright (c) 2006-2017  Thomas Pircher  <tehpeh-web@tty1.net>
--
--  Permission is hereby granted, free of charge, to any person obtaining a copy
--  of this software and associated documentation files (the "Software"), to
--  deal in the Software without restriction, including without limitation the
--  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
--  sell copies of the Software, and to permit persons to whom the Software is
--  furnished to do so, subject to the following conditions:
--
--  The above copyright notice and this permission notice shall be included in
--  all copies or substantial portions of the Software.
--
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
--  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
--  IN THE SOFTWARE.

with Interfaces;

package PyCRC.Algorithms
  with SPARK_Mode
is

   --  Lookup tables are indexed by 1, 2, 4 or 8 bits. The calculator uses
   --  8, which is what the Python implementation computes. Generated code
   --  can use any of the four widths.
   subtype Table_Index_Width is Positive
     with Static_Predicate => Table_Index_Width in 1 | 2 | 4 | 8;

   type Word_Array is array (Natural range <>) of Interfaces.Unsigned_64;

   type Calculator is private;

   function Register_Width (Calc : Calculator) return Width_Type with
     Global => null;

   function Register_Mask (Calc : Calculator) return Interfaces.Unsigned_64 with
     Global => null,
     Post   => Register_Mask'Result = Bits_Mask (Register_Width (Calc));

   function Create
     (Width           : Width_Type;
      Poly            : Interfaces.Unsigned_64;
      Reflect_In      : Boolean;
      Xor_In          : Interfaces.Unsigned_64;
      Reflect_Out     : Boolean;
      Xor_Out         : Interfaces.Unsigned_64;
      Table_Idx_Width : Table_Index_Width := 8) return Calculator
   with
     Global => null,
     Post   =>
       Register_Width (Create'Result) = Width
       and then Register_Mask (Create'Result) = Bits_Mask (Width);

   function Bit_By_Bit
     (Calc : Calculator; Data : Byte_Array) return Interfaces.Unsigned_64
   with
     Global => null,
     Post   => Bit_By_Bit'Result <= Register_Mask (Calc);

   function Bit_By_Bit_Fast
     (Calc : Calculator; Data : Byte_Array) return Interfaces.Unsigned_64
   with
     Global => null,
     Post   => Bit_By_Bit_Fast'Result <= Register_Mask (Calc);

   function Table_Driven
     (Calc : Calculator; Data : Byte_Array) return Interfaces.Unsigned_64
   with
     Global => null,
     Post   => Table_Driven'Result <= Register_Mask (Calc);

   --  Streaming form of the direct (bit-by-bit-fast) algorithm. File checks
   --  feed the register a chunk at a time, matching pycrc's --check-file.
   function Direct_Init (Calc : Calculator) return Interfaces.Unsigned_64 with
     Global => null,
     Post   => Direct_Init'Result <= Register_Mask (Calc);

   function Direct_Update
     (Calc     : Calculator;
      Register : Interfaces.Unsigned_64;
      Data     : Byte_Array) return Interfaces.Unsigned_64
   with
     Global => null,
     Pre    => Register <= Register_Mask (Calc),
     Post   => Direct_Update'Result <= Register_Mask (Calc);

   function Direct_Finalize
     (Calc     : Calculator;
      Register : Interfaces.Unsigned_64) return Interfaces.Unsigned_64
   with
     Global => null,
     Pre    => Register <= Register_Mask (Calc),
     Post   => Direct_Finalize'Result <= Register_Mask (Calc);

   function Lookup_Table
     (Width       : Width_Type;
      Poly        : Interfaces.Unsigned_64;
      Reflect_In  : Boolean;
      Index_Width : Table_Index_Width := 8) return Word_Array
   with
     Global => null,
     Post   =>
       Lookup_Table'Result'First = 0
       and then Lookup_Table'Result'Last = 2 ** Index_Width - 1;

private

   type Calculator is record
      Width       : Width_Type := 8;
      Index_Width : Table_Index_Width := 8;
      Poly        : Interfaces.Unsigned_64 := 0;
      Xor_In      : Interfaces.Unsigned_64 := 0;
      Xor_Out     : Interfaces.Unsigned_64 := 0;
      Mask        : Interfaces.Unsigned_64 := 16#FF#;
      MSB         : Interfaces.Unsigned_64 := 16#80#;
      Reflect_In  : Boolean := False;
      Reflect_Out : Boolean := False;
      Table       : Word_Array (0 .. 255) := [others => 0];
   end record
     with Type_Invariant =>
       Calculator.Mask = Bits_Mask (Calculator.Width)
       and then Calculator.MSB = MSB_Mask (Calculator.Width)
       and then (Calculator.Poly and Calculator.Mask) = Calculator.Poly
       and then (Calculator.Xor_In and Calculator.Mask) = Calculator.Xor_In
       and then (Calculator.Xor_Out and Calculator.Mask) = Calculator.Xor_Out;

end PyCRC.Algorithms;

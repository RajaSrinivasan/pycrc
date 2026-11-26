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

package body PyCRC.Algorithms
  with SPARK_Mode
is

   use Interfaces;

   subtype Bit_Count is Natural range 1 .. 64;

   function Shl (Value : Unsigned_64; Amount : Natural) return Unsigned_64 with
     Global => null,
     Post   =>
       (if Amount = 0 then Shl'Result = Value
        elsif Amount >= 64 then Shl'Result = 0
        else Shl'Result = Shift_Left (Value, Amount))
   is
   begin
      if Amount = 0 then
         return Value;
      elsif Amount >= 64 then
         return 0;
      else
         return Shift_Left (Value, Amount);
      end if;
   end Shl;

   function Shr (Value : Unsigned_64; Amount : Natural) return Unsigned_64 with
     Global => null,
     Post   =>
       (if Amount = 0 then Shr'Result = Value
        elsif Amount >= 64 then Shr'Result = 0
        else Shr'Result = Shift_Right (Value, Amount))
   is
   begin
      if Amount = 0 then
         return Value;
      elsif Amount >= 64 then
         return 0;
      else
         return Shift_Right (Value, Amount);
      end if;
   end Shr;

   --  Low 8 bits, so the conversion to a table slot cannot overflow.
   function To_Index (Value : Unsigned_64) return Natural with
     Global => null,
     Post   =>
       To_Index'Result <= 255
       and then Unsigned_64 (To_Index'Result) = (Value and 16#FF#)
   is
      Masked : constant Unsigned_64 := Value and 16#FF#;
   begin
      return Natural (Masked);
   end To_Index;

   function Reflect (Data : Unsigned_64; Bits : Bit_Count) return Unsigned_64 with
     Global => null
   is
      Result : Unsigned_64 := Data and 1;
      Value  : Unsigned_64 := Data;
   begin
      for Step in 1 .. Bits - 1 loop
         Value := Shr (Value, 1);
         Result := Shl (Result, 1) or (Value and 1);
      end loop;
      return Result;
   end Reflect;

   function CRC_Shift (Width : Width_Type) return Natural is
     (if Width < 8 then 8 - Width else 0);

   function Lookup_Table
     (Width       : Width_Type;
      Poly        : Unsigned_64;
      Reflect_In  : Boolean;
      Index_Width : Table_Index_Width := 8) return Word_Array
   is
      Length : constant Natural := 2 ** Index_Width;
      Result : Word_Array (0 .. Length - 1);
      Mask   : constant Unsigned_64 := Bits_Mask (Width);
      MSB    : constant Unsigned_64 := MSB_Mask (Width);
      Shift  : constant Natural := CRC_Shift (Width);
      Poly_M : constant Unsigned_64 := Poly and Mask;
      --  width - index_width + crc_shift, written so both branches subtract
      --  a smaller value from a larger one.
      Amount : constant Natural :=
        (if Width < 8 then 8 - Natural (Index_Width)
         else Natural (Width) - Natural (Index_Width));
   begin
      for I in Result'Range loop
         declare
            Reg : Unsigned_64 := Unsigned_64 (I);
         begin
            if Reflect_In then
               Reg := Reflect (Reg, Index_Width);
            end if;
            pragma Assert (Amount <= 63);
            Reg := Shl (Reg, Amount);
            for Step in 1 .. Index_Width loop
               if (Reg and Shl (MSB, Shift)) /= 0 then
                  Reg := Shl (Reg, 1) xor Shl (Poly_M, Shift);
               else
                  Reg := Shl (Reg, 1);
               end if;
            end loop;
            if Reflect_In then
               Reg := Shl (Reflect (Shr (Reg, Shift), Width), Shift);
            end if;
            Result (I) := Shr (Reg, Shift) and Mask;
         end;
      end loop;
      return Result;
   end Lookup_Table;

   function Register_Width (Calc : Calculator) return Width_Type is
     (Calc.Width);

   function Register_Mask (Calc : Calculator) return Unsigned_64 is
     (Calc.Mask);

   function Create
     (Width           : Width_Type;
      Poly            : Unsigned_64;
      Reflect_In      : Boolean;
      Xor_In          : Unsigned_64;
      Reflect_Out     : Boolean;
      Xor_Out         : Unsigned_64;
      Table_Idx_Width : Table_Index_Width := 8) return Calculator
   is
      Mask : constant Unsigned_64 := Bits_Mask (Width);
      Calc : Calculator;
      Tbl  : constant Word_Array :=
        Lookup_Table (Width, Poly and Mask, Reflect_In, Table_Idx_Width);
   begin
      Calc.Width := Width;
      Calc.Index_Width := Table_Idx_Width;
      Calc.Poly := Poly and Mask;
      Calc.Xor_In := Xor_In and Mask;
      Calc.Xor_Out := Xor_Out and Mask;
      Calc.Mask := Mask;
      Calc.MSB := MSB_Mask (Width);
      Calc.Reflect_In := Reflect_In;
      Calc.Reflect_Out := Reflect_Out;
      Calc.Table := [others => 0];
      Calc.Table (Tbl'Range) := Tbl;
      return Calc;
   end Create;

   function Nondirect_Init (Calc : Calculator) return Unsigned_64 is
      Reg : Unsigned_64 := Calc.Xor_In;
   begin
      for Unused in 1 .. Calc.Width loop
         declare
            Bit : constant Boolean := (Reg and 1) /= 0;
         begin
            if Bit then
               Reg := Reg xor Calc.Poly;
            end if;
            Reg := Shr (Reg, 1);
            if Bit then
               Reg := Reg or Calc.MSB;
            end if;
         end;
      end loop;
      return Reg and Calc.Mask;
   end Nondirect_Init;

   function Bit_By_Bit_Update
     (Calc     : Calculator;
      Register : Unsigned_64;
      Data     : Byte_Array) return Unsigned_64
   is
      Reg : Unsigned_64 := Register;
   begin
      for J in Data'Range loop
         declare
            C : Unsigned_64 := Unsigned_64 (Data (J));
         begin
            if Calc.Reflect_In then
               C := Reflect (C, 8);
            end if;
            for I in 0 .. 7 loop
               declare
                  Top : constant Boolean := (Reg and Calc.MSB) /= 0;
                  Bit : constant Unsigned_64 := Shr (C, 7 - I) and 1;
               begin
                  Reg := (Shl (Reg, 1) or Bit) and Calc.Mask;
                  if Top then
                     Reg := Reg xor Calc.Poly;
                  end if;
               end;
            end loop;
         end;
      end loop;
      return Reg and Calc.Mask;
   end Bit_By_Bit_Update;

   function Bit_By_Bit_Finalize
     (Calc : Calculator; Register : Unsigned_64) return Unsigned_64
   is
      Reg : Unsigned_64 := Register;
   begin
      for Unused in 1 .. Calc.Width loop
         declare
            Top : constant Boolean := (Reg and Calc.MSB) /= 0;
         begin
            Reg := Shl (Reg, 1) and Calc.Mask;
            if Top then
               Reg := Reg xor Calc.Poly;
            end if;
         end;
      end loop;
      if Calc.Reflect_Out then
         Reg := Reflect (Reg, Calc.Width);
      end if;
      return (Reg xor Calc.Xor_Out) and Calc.Mask;
   end Bit_By_Bit_Finalize;

   function Bit_By_Bit
     (Calc : Calculator; Data : Byte_Array) return Unsigned_64
   is
   begin
      return Bit_By_Bit_Finalize
        (Calc, Bit_By_Bit_Update (Calc, Nondirect_Init (Calc), Data));
   end Bit_By_Bit;

   function Direct_Init (Calc : Calculator) return Unsigned_64 is
     (Calc.Xor_In);

   function Direct_Update
     (Calc     : Calculator;
      Register : Unsigned_64;
      Data     : Byte_Array) return Unsigned_64
   is
      Reg : Unsigned_64 := Register;
   begin
      for J in Data'Range loop
         declare
            C : Unsigned_64 := Unsigned_64 (Data (J));
         begin
            if Calc.Reflect_In then
               C := Reflect (C, 8);
            end if;
            for I in 0 .. 7 loop
               declare
                  Top : Boolean := (Reg and Calc.MSB) /= 0;
               begin
                  if (C and Shl (1, 7 - I)) /= 0 then
                     Top := not Top;
                  end if;
                  Reg := Shl (Reg, 1) and Calc.Mask;
                  if Top then
                     Reg := Reg xor Calc.Poly;
                  end if;
               end;
            end loop;
         end;
      end loop;
      return Reg and Calc.Mask;
   end Direct_Update;

   function Direct_Finalize
     (Calc : Calculator; Register : Unsigned_64) return Unsigned_64
   is
      Reg : Unsigned_64 := Register;
   begin
      if Calc.Reflect_Out then
         Reg := Reflect (Reg, Calc.Width);
      end if;
      return (Reg xor Calc.Xor_Out) and Calc.Mask;
   end Direct_Finalize;

   function Bit_By_Bit_Fast
     (Calc : Calculator; Data : Byte_Array) return Unsigned_64
   is
   begin
      return Direct_Finalize
        (Calc, Direct_Update (Calc, Direct_Init (Calc), Data));
   end Bit_By_Bit_Fast;

   function Table_Driven
     (Calc : Calculator; Data : Byte_Array) return Unsigned_64
   is
      Idx_Width  : constant Positive := Calc.Index_Width;
      Table_Mask : constant Unsigned_64 := Shl (1, Idx_Width) - 1;
      Chunks     : constant Natural := 8 / Idx_Width;
      Reg        : Unsigned_64 :=
        (if Calc.Reflect_In
         then Reflect (Calc.Xor_In, Calc.Width)
         else Calc.Xor_In);
   begin
      Reg := Reg and Calc.Mask;
      for J in Data'Range loop
         declare
            Octet : constant Byte := Data (J);
         begin
         if Calc.Reflect_In then
            for I in 0 .. Chunks - 1 loop
               declare
                  Shifted : constant Unsigned_64 :=
                    Shr (Unsigned_64 (Octet), I * Idx_Width);
                  Idx : constant Natural :=
                    To_Index ((Reg xor Shifted) and Table_Mask);
                  Mix : constant Unsigned_64 :=
                    (if Calc.Width <= Idx_Width
                     then 0
                     else Shr (Reg, Idx_Width));
               begin
                  Reg := (Calc.Table (Idx) xor Mix) and Calc.Mask;
               end;
            end loop;
         else
            for I in 0 .. Chunks - 1 loop
               declare
                  Product : constant Natural := (I + 1) * Idx_Width;
                  Byte_Shift : constant Natural :=
                    (if Product > 8 then 0 else 8 - Product);
                  Shifted : constant Unsigned_64 :=
                    Shr (Unsigned_64 (Octet), Byte_Shift);
                  Wide : constant Natural := Natural (Calc.Width);
                  Idx_N : constant Natural := Natural (Idx_Width);
                  Distance : constant Natural :=
                    (if Idx_N > Wide then Idx_N - Wide else Wide - Idx_N);
                  CRC_Shifted : constant Unsigned_64 :=
                    (if Idx_N > Wide
                     then Shl (Reg, Distance)
                     else Shr (Reg, Distance));
                  Idx : constant Natural :=
                    To_Index ((CRC_Shifted xor Shifted) and Table_Mask);
                  Mix : constant Unsigned_64 :=
                    (if Calc.Width <= Idx_Width
                     then 0
                     else Shl (Reg, Idx_Width));
               begin
                  Reg := (Calc.Table (Idx) xor Mix) and Calc.Mask;
               end;
            end loop;
         end if;
         end;
      end loop;
      if Calc.Reflect_In /= Calc.Reflect_Out then
         Reg := Reflect (Reg, Calc.Width);
      end if;
      return (Reg xor Calc.Xor_Out) and Calc.Mask;
   end Table_Driven;

end PyCRC.Algorithms;

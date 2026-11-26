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

with Ada.Text_IO;

package body PyCRC
  with SPARK_Mode
is

   procedure Die (Message : String) with SPARK_Mode => Off is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "pycrc: error: " & Message);
      raise Parameter_Error;
   end Die;

   procedure Warn (Message : String) with SPARK_Mode => Off is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "pycrc: warning: " & Message);
   end Warn;

   function Bits_Mask (Width : Width_Type) return Interfaces.Unsigned_64 is
      use Interfaces;
   begin
      if Width = 64 then
         return Unsigned_64'Last;
      end if;
      return Shift_Left (Unsigned_64'(1), Width) - 1;
   end Bits_Mask;

   function MSB_Mask (Width : Width_Type) return Interfaces.Unsigned_64 is
      use Interfaces;
   begin
      return Shift_Left (Unsigned_64'(1), Width - 1);
   end MSB_Mask;

   function Padded_Hex
     (Value : Interfaces.Unsigned_64; Nibble_Count : Positive) return String
   with SPARK_Mode => Off
   is
      use Interfaces;
      Hexits : constant String := "0123456789abcdef";
      Buffer : String (1 .. Nibble_Count) := [others => '0'];
      Rest   : Unsigned_64 := Value;
   begin
      for I in reverse Buffer'Range loop
         Buffer (I) := Hexits (Natural (Rest and 16#F#) + 1);
         Rest := Shift_Right (Rest, 4);
      end loop;
      return "0x" & Buffer;
   end Padded_Hex;

   function Hex_Image (Value : Interfaces.Unsigned_64) return String
   with SPARK_Mode => Off
   is
      Full  : constant String := Padded_Hex (Value, 16);
      Start : Positive := Full'First + 2;
   begin
      if Value = 0 then
         return "0x0";
      end if;
      while Start < Full'Last and then Full (Start) = '0' loop
         Start := Start + 1;
      end loop;
      return "0x" & Full (Start .. Full'Last);
   end Hex_Image;

   function Hex_Image
     (Value : Interfaces.Unsigned_64; Width : Width_Type) return String
   with SPARK_Mode => Off
   is
      Nibble_Count : constant Positive := Positive'Max (1, (Width + 3) / 4);
   begin
      return Padded_Hex (Value, Nibble_Count);
   end Hex_Image;

   function To_Bytes (Text : String) return Byte_Array
   with SPARK_Mode => Off
   is
      Result : Byte_Array (1 .. Text'Length);
   begin
      for I in Text'Range loop
         Result (Result'First + (I - Text'First)) :=
           Byte (Character'Pos (Text (I)));
      end loop;
      return Result;
   end To_Bytes;

end PyCRC;

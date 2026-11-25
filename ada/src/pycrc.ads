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

package PyCRC
  with SPARK_Mode
is
   use type Interfaces.Unsigned_64;

   Version        : constant String := "0.11.0";
   Version_String : constant String := "pycrc v0.11.0 (Ada)";
   URL            : constant String := "https://pycrc.org";

   --  Rocksoft parameters wider than 64 bits are rejected. Every model
   --  shipped with pycrc fits in this range.
   subtype Width_Type is Positive range 1 .. 64;

   subtype Byte is Interfaces.Unsigned_8;
   type Byte_Array is array (Positive range <>) of Byte;

   Parameter_Error : exception;

   --  Text output is outside SPARK. Callers are the command-line units,
   --  which are themselves SPARK_Mode Off.
   procedure Die (Message : String) with
     SPARK_Mode => Off,
     No_Return;
   procedure Warn (Message : String) with
     SPARK_Mode => Off;

   function Bits_Mask (Width : Width_Type) return Interfaces.Unsigned_64 with
     Global => null,
     Post   =>
       (if Width = 64 then Bits_Mask'Result = Interfaces.Unsigned_64'Last
        else Bits_Mask'Result = 2 ** Width - 1);

   function MSB_Mask (Width : Width_Type) return Interfaces.Unsigned_64 with
     Global => null,
     Post   =>
       MSB_Mask'Result = Interfaces.Shift_Left (Interfaces.Unsigned_64'(1), Width - 1);

   --  Unconstrained strings are not a useful SPARK proof target here: the
   --  image is only for printing, and GNATprove declines contextual analysis
   --  of unconstrained function results.
   function Hex_Image (Value : Interfaces.Unsigned_64) return String with
     SPARK_Mode => Off;

   function Hex_Image
     (Value : Interfaces.Unsigned_64; Width : Width_Type) return String
   with
     SPARK_Mode => Off;

   function To_Bytes (Text : String) return Byte_Array with
     SPARK_Mode => Off;

end PyCRC;

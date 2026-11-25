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

package PyCRC is

   Version        : constant String := "0.11.0";
   Version_String : constant String := "pycrc v0.11.0 (Ada)";
   URL            : constant String := "https://pycrc.org";

   --  Rocksoft parameters wider than 64 bits are rejected. Every model
   --  shipped with pycrc fits in this range.
   subtype Width_Type is Positive range 1 .. 64;

   subtype Byte is Interfaces.Unsigned_8;
   type Byte_Array is array (Positive range <>) of Byte;

   Parameter_Error : exception;

   procedure Die (Message : String) with No_Return;
   procedure Warn (Message : String);

   function Bits_Mask (Width : Width_Type) return Interfaces.Unsigned_64;
   function MSB_Mask (Width : Width_Type) return Interfaces.Unsigned_64;

   --  Lower-case hexadecimal with a 0x prefix and no leading zeros.
   function Hex_Image (Value : Interfaces.Unsigned_64) return String;

   --  Lower-case hexadecimal padded to the nibble width of a CRC register.
   function Hex_Image
     (Value : Interfaces.Unsigned_64; Width : Width_Type) return String;

   function To_Bytes (Text : String) return Byte_Array;

end PyCRC;

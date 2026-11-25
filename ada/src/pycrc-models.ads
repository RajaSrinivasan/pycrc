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

with Ada.Strings.Unbounded;
with Interfaces;

package PyCRC.Models is

   type Model is record
      Name        : Ada.Strings.Unbounded.Unbounded_String;
      Width       : Width_Type;
      Poly        : Interfaces.Unsigned_64;
      Reflect_In  : Boolean;
      Xor_In      : Interfaces.Unsigned_64;
      Reflect_Out : Boolean;
      Xor_Out     : Interfaces.Unsigned_64;
      Check       : Interfaces.Unsigned_64;
   end record;

   function Count return Positive;
   function At_Index (Index : Positive) return Model;

   --  Case-insensitive. Returns False when Name is not a known model.
   function Lookup (Name : String; Item : out Model) return Boolean;

   function Names (Separator : String := ", ") return String;

end PyCRC.Models;

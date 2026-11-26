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

package PyCRC.Models
  with SPARK_Mode
is

   Max_Model_Name : constant := 16;

   --  Fixed text so the catalogue does not depend on Unbounded_String,
   --  which is outside SPARK.
   type Model_Name is record
      Length : Natural range 0 .. Max_Model_Name := 0;
      Text   : String (1 .. Max_Model_Name) := [others => ' '];
   end record;

   function To_String (Name : Model_Name) return String with
     Global => null,
     Pre    => Name.Length <= Max_Model_Name,
     Post   => To_String'Result'Length = Name.Length;

   type Model is record
      Name        : Model_Name;
      Width       : Width_Type;
      Poly        : Interfaces.Unsigned_64;
      Reflect_In  : Boolean;
      Xor_In      : Interfaces.Unsigned_64;
      Reflect_Out : Boolean;
      Xor_Out     : Interfaces.Unsigned_64;
      Check       : Interfaces.Unsigned_64;
   end record;

   function Count return Positive with
     Global => null;

   function At_Index (Index : Positive) return Model with
     Global => null,
     Pre    => Index <= Count;

   --  Case-insensitive. Found is False when Name is not a known model.
   --  A function cannot have an out parameter in SPARK, so this is a procedure.
   procedure Lookup (Name : String; Item : out Model; Found : out Boolean) with
     Global  => null,
     Depends => (Found => Name, Item => Name);

   --  Help text only. Unbounded concatenation of a caller-chosen separator
   --  is not part of the CRC model, so this stays outside SPARK.
   function Names (Separator : String := ", ") return String with
     SPARK_Mode => Off;

end PyCRC.Models;

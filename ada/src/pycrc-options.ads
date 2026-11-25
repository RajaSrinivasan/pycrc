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

package PyCRC.Options is

   type Algorithm_Selection is record
      Bit_By_Bit      : Boolean := False;
      Bit_By_Bit_Fast : Boolean := False;
      Table_Driven    : Boolean := False;
   end record;

   type Action_Kind is (Check_String, Check_Hexstring, Check_File, Generate);
   type Generate_Kind is (Spec, Body_Part, Driver, Table);

   Max_Includes : constant := 32;

   type Include_Array is
     array (1 .. Max_Includes) of Ada.Strings.Unbounded.Unbounded_String;

   type Settings is record
      Stop             : Boolean := False;
      Verbose          : Boolean := False;
      Force_Poly       : Boolean := False;
      Has_Width        : Boolean := False;
      Has_Poly         : Boolean := False;
      Has_Reflect_In   : Boolean := False;
      Has_Xor_In       : Boolean := False;
      Has_Reflect_Out  : Boolean := False;
      Has_Xor_Out      : Boolean := False;
      Width            : Natural := 0;
      Poly             : Interfaces.Unsigned_64 := 0;
      Xor_In           : Interfaces.Unsigned_64 := 0;
      Xor_Out          : Interfaces.Unsigned_64 := 0;
      Reflect_In       : Boolean := False;
      Reflect_Out      : Boolean := False;
      Table_Idx_Width  : Positive := 8;
      Algorithm        : Algorithm_Selection;
      Action           : Action_Kind := Check_String;
      Generate         : Generate_Kind := Spec;
      Check_String     : Ada.Strings.Unbounded.Unbounded_String;
      Check_File       : Ada.Strings.Unbounded.Unbounded_String;
      Symbol_Prefix    : Ada.Strings.Unbounded.Unbounded_String;
      Output_File      : Ada.Strings.Unbounded.Unbounded_String;
      Include_Count    : Natural := 0;
      Includes         : Include_Array;
   end record;

   function Parse return Settings;

   --  The --verbose block. Parameters are fully defined.
   function Parameter_Block (Opt : Settings) return String;

end PyCRC.Options;

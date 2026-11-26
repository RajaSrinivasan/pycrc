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

with Ada.Command_Line;
with Ada.Text_IO;
with Interfaces;
with PyCRC.Algorithms;
with PyCRC.Models;

--  Prints a report with Text_IO. The comparisons themselves call SPARK
--  subprograms.
procedure PyCRC.Self_Check
  with SPARK_Mode => Off
is

   use Ada.Text_IO;

   Failures : Natural := 0;

   function Pad (Text : String; Width : Positive) return String is
     (if Text'Length >= Width
      then Text
      else Text & [1 .. Width - Text'Length => ' ']);

   procedure Report (Name, Expected, Got, Status : String) is
   begin
      Put_Line
        (Pad (Name, 16) & "  " & Pad (Expected, 20) & "  "
         & Pad (Got, 20) & "  " & Status);
   end Report;

   procedure Fail (Message : String) is
   begin
      Put_Line (Standard_Error, "pycrc_self_check: " & Message);
      Failures := Failures + 1;
   end Fail;

   function Calc_Of (Item : Models.Model) return Algorithms.Calculator is
     (Algorithms.Create
        (Width       => Item.Width,
         Poly        => Item.Poly,
         Reflect_In  => Item.Reflect_In,
         Xor_In      => Item.Xor_In,
         Reflect_Out => Item.Reflect_Out,
         Xor_Out     => Item.Xor_Out));
begin
   Put_Line
     (Pad ("model", 16) & "  " & Pad ("check", 20) & "  "
      & Pad ("ada", 20) & "  status");

   for Index in 1 .. Models.Count loop
      declare
         Item : constant Models.Model := Models.At_Index (Index);
         Name : constant String := Models.To_String (Item.Name);
         Calc : constant Algorithms.Calculator := Calc_Of (Item);
         Data : constant Byte_Array := To_Bytes ("123456789");
         BBB  : constant Interfaces.Unsigned_64 :=
           Algorithms.Bit_By_Bit (Calc, Data);
         BBF  : constant Interfaces.Unsigned_64 :=
           Algorithms.Bit_By_Bit_Fast (Calc, Data);
         Tbl  : constant Interfaces.Unsigned_64 :=
           Algorithms.Table_Driven (Calc, Data);
         Expect : constant String := Hex_Image (Item.Check);
      begin
         if BBB = BBF and then BBF = Tbl and then BBB = Item.Check then
            Report (Name, Expect, Hex_Image (BBB), "ok");
         else
            Report (Name, Expect, Hex_Image (BBB), "FAIL");
            Fail (Name & " bbb=" & Hex_Image (BBB) & " bbf=" & Hex_Image (BBF)
                  & " tbl=" & Hex_Image (Tbl) & " check=" & Expect);
         end if;

         --  The direct algorithm must survive being fed in more than one chunk.
         declare
            Mid : constant Natural := Data'Length / 2;
            Reg : Interfaces.Unsigned_64 := Algorithms.Direct_Init (Calc);
         begin
            Reg := Algorithms.Direct_Update (Calc, Reg, Data (1 .. Mid));
            Reg :=
              Algorithms.Direct_Update (Calc, Reg, Data (Mid + 1 .. Data'Last));
            if Algorithms.Direct_Finalize (Calc, Reg) /= BBF then
               Fail (Name & " chunked bit-by-bit-fast disagreed");
            end if;
         end;
      end;
   end loop;

   for Index in 1 .. Models.Count loop
      declare
         Item : constant Models.Model := Models.At_Index (Index);
         Name : constant String := Models.To_String (Item.Name);
         Calc : constant Algorithms.Calculator := Calc_Of (Item);

         procedure Agree (Sample : Byte_Array) is
            BBB : constant Interfaces.Unsigned_64 :=
              Algorithms.Bit_By_Bit (Calc, Sample);
            BBF : constant Interfaces.Unsigned_64 :=
              Algorithms.Bit_By_Bit_Fast (Calc, Sample);
            Tbl : constant Interfaces.Unsigned_64 :=
              Algorithms.Table_Driven (Calc, Sample);
         begin
            if BBB /= BBF or else BBF /= Tbl then
               Fail (Name & " algorithms diverged on a corner-case input: "
                     & Hex_Image (BBB) & " " & Hex_Image (BBF) & " "
                     & Hex_Image (Tbl));
            end if;
         end Agree;
      begin
         Agree ([1 .. 0 => 0]);
         Agree ([1 => 0]);
         Agree ([1 => 1]);
         Agree ([1 => 16#FF#]);
         Agree ([1 .. 4 => 0]);
         Agree (To_Bytes ("The quick brown fox"));
      end;
   end loop;

   if Failures = 0 then
      Put_Line ("All" & Models.Count'Image & " models matched.");
   else
      Put_Line (Standard_Error, Failures'Image & " failure(s).");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end PyCRC.Self_Check;

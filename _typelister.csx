var asm = System.Reflection.Assembly.LoadFrom(args[0]);
foreach (var t in asm.GetExportedTypes().Where(t => t.Namespace?.Contains("Copilot") == true).OrderBy(t => t.FullName))
{
    Console.WriteLine(t.FullName);
    foreach (var p in t.GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance))
        Console.WriteLine($"  .{p.Name} : {p.PropertyType.Name}");
}

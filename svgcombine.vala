/**
 * svgcombine
 *
 * Tiny CLI utility to combine multiple input SVG files into one big SVG definitin file ("sprite") containing
 * the input SVGs as <symbol />'s, so they can be used e.g. from HTML as <svg><use xlink:href="#id"></use></svg>
 * 
 * @author Johannes Braun <johannes.braun@hannenz.de>
 * @version 2017-01-24
 * 
 * Dependencies: [libxmlbird](https://github.com/johanmattssonm/xmlbird/) (Ubuntu: sudo apt install libxmlbird)
 *
 * Compile:
 * `$ valac -o svgcombine svgcombine.vala --pkg gio-2.0 --pkg xmlbird`
 *
 */
using GLib;
using B;

public class SVGCombine {

	protected List<File> files;

	protected static string? outfile_path = null;

	protected static string prefix = "";

	protected static bool version = false;

	private const GLib.OptionEntry[] options = {
		{ "version", 'v', 0, OptionArg.NONE, ref version, "Display version number", null },
		{ "output",  'o', 0, OptionArg.FILENAME, ref outfile_path, "Specify a file to write the resulting svg to. Outputs to stdout if omitted", null },
		{ "prefix", 'p', 0, OptionArg.STRING, ref prefix, "Prefix each symbol's id with this string", null },
		{ null }
	};

	public SVGCombine(ref unowned string[] args) {
		
		if (!parse_options(ref args)) {
			stderr.printf("Errors. Exiting\n");
			return;
		}

		if (version == true) {
			stdout.printf("1.0\n");
			return;
		}

		debug ("Using prefix: %s".printf(prefix));
		debug ("Output to:    %s".printf(outfile_path));

		foreach (string filename in args[1:args.length]) {
			File file = File.new_for_path(filename);
			if (file.query_exists()) {
				files.append(file);
			}
			else {
				stderr.printf("File does not exist: %s\n", filename);
			}
		}
	}

	private bool parse_options(ref unowned string[] args) {
		try {
			var opt_context = new OptionContext("- SVG Combine");
			opt_context.set_help_enabled(true);
			opt_context.add_main_entries(options, null);
			opt_context.parse(ref args);
		}
		catch (OptionError e) {
			stderr.printf("Error: %s\n".printf(e.message));
			return false;
		}
		return true;
	}

	protected string filename2slug(string filename) {

		string r = "";
		string name = filename.replace(".svg", "");
		
		try {
			Regex regex = new Regex("\\W+");
			r = regex.replace(name, name.length, 0, "-");
		}
		catch (Error e) {
			warning(e.message);
		
		}
		return prefix + r;
	}

	public bool run() {

		if (files.length() == 0) {
			stderr.printf("No input files specified\n");
			return false;
		}

		string out_svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"0\" height=\"0\" style=\"width:0;height:0;display:block\">\n";

		foreach (File file in files) {

			// Open the file
			try {
				string svgstring;
				FileUtils.get_contents(file.get_path(), out svgstring, null);

				string id = filename2slug(file.get_basename());

				// Parse XML
				var parser = new XmlParser(svgstring);
				if (!parser.validate()) {
					error("%s: Invalid SVG".printf(file.get_path()));
				}

				Tag root = parser.get_root_tag();
				string viewBoxAttribute = "";
				foreach (Attribute attr in root.get_attributes()) {
					if (attr.get_name() == "viewBox") {
						viewBoxAttribute = attr.get_content();
						break;
					}
				}

				out_svg += "<symbol id=\"%s\" viewBox=\"%s\">%s</symbol>\n".printf(id, viewBoxAttribute, root.get_content());
			}
			catch (Error e) {
				warning(e.message);
			}
		}
		out_svg += "</svg>";

		// Write output to either file or stdout
		File outfile;
		FileOutputStream ostream;

		if (outfile_path != null) {
			try {
				outfile = File.new_for_path(outfile_path);
				ostream = outfile.replace(null, false, 0, null);
			}
			catch (Error e) {
				warning ("Failed to create output file: %s", e.message);
				return false;
			}

			try {
				uint8[] data = out_svg.data;
				long written = 0;
				while (written < data.length) {
					written += ostream.write(data[written:data.length]);
				}
			}
			catch (IOError e) {
				warning ("Failed to write to output file: %s", e.message);
				return false;
			}
		}
		else {
			stdout.printf("%s\n", out_svg);
		}
		return true;
	}

	static int main (string[] args) {
		
		var app = new SVGCombine(ref args);
		return app.run() ? 0 : -1;
	}
}


/**
 * svgcombine
 *
 * Tiny CLI utility to combine multiple input SVG files into one big SVG definitin file ("sprite") containing
 * the input SVGs as <symbol />'s, so they can be used e.g. from HTML as <svg><use xlink:href="#id"></use></svg>
 * 
 * @author Johannes Braun <johannes.braun@hannenz.de>
 * @version 2017-01-24
 * 
 * Dependencies: [libxmlbird](https://github.com/johanmattssonm/xmlbird/)
 * (Ubuntu: sudo apt install libxmlbird-dev)
 *
 * Compile:
 * `$ valac -o svgcombine svgcombine.vala --pkg gio-2.0 --pkg xmlbird`
 *
 */
using GLib;
using B;

public class SVGCombine {


	// Options
	protected static string? outfile_path = null;
	protected static string prefix = "";
	protected static bool show_version = false;
	protected static  string svgtag = """<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="0" height="0" style="width:0;height:0;display:block">""";

	protected List<File> files;
	private List<string> used_ids = new List<string>();
	protected List<string> defs;
	protected List<string> symbols;

	private const GLib.OptionEntry[] options = {
		{ "version", 'v', 0, OptionArg.NONE, ref show_version, "Display version number", null },
		{ "output",  'o', 0, OptionArg.FILENAME, ref outfile_path, "Specify a file to write the resulting svg to. Outputs to stdout if omitted", null },
		{ "prefix", 'p', 0, OptionArg.STRING, ref prefix, "Prefix each symbol's id with this string", null },
		{ "svgtag", 's', 0, OptionArg.STRING, ref svgtag, "The opening SVG tag to be used" },
		{ null }
	};

	/**
	 * Constructor
	 */
	public SVGCombine(ref unowned string[] args) {
		
		// Parse commandline options
		if (!parse_options(ref args)) {
			stderr.printf("Errors. Exiting\n");
			return;
		}

		if (show_version == true) {
			stdout.printf("1.0\n");
			return;
		}

		debug("Using prefix: %s".printf(prefix));
		debug("Output to:    %s".printf(outfile_path));

		// Process remaining arguments as input files
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

	
	/**
	 * Parse commandlinle options
	 */
	private bool parse_options(ref unowned string[] args) {
		try {
			var opt_context = new OptionContext("input-files");
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

	/**
	 * Generate an ID from filename
	 *
	 * @param string	The filename
	 * @return string	The ID
	 */
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

		// Assert unique IDs
		int c = 2;
		string id = r;
		while (is_used(id)) {
			id = "%s-%u".printf(r, c++);
		}
		used_ids.prepend(id);

		return prefix + id;
	}

	/**
	 * Check if a given id is already in use
	 * 
	 * @param string id		The id to check
	 * @return bool
	 */
	private bool is_used(string id) {
		bool is_used = false;
		foreach (string used_id in used_ids) {
			if (id == used_id) {
				is_used = true;
				break;
			}
		}
		return is_used;
	}

	public bool run() {

		if (files.length() == 0) {
			stderr.printf("No input files specified\n");
			return false;
		}


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

				// Get viewbox attribute
				string viewBoxAttribute = "";
				foreach (Attribute attr in root.get_attributes()) {
					if (attr.get_name() == "viewBox") {
						viewBoxAttribute = attr.get_content();
						break;
					}
				}

				// Extract <def>s
				// Kill metadata
				foreach (Tag child in root) {
					if (child.get_name() == "defs") {
						defs.append(child.get_content());
					}
				}

				string symbol = """<symbol id="%s" viewBox="%s">%s</symbol>""".printf(id, viewBoxAttribute, root.get_content());
				symbols.append(symbol);
			}
			catch (Error e) {
				warning("Error: " + e.message);
			}
		}


		// Assemble output SVG
		string out_svg = svgtag + "\n";
		// write <def>s
		out_svg += "<defs>\n";
		foreach (string def in defs) {
			out_svg += def;
		}
		out_svg += "</defs>\n";
		foreach (string symbol in symbols) {
			out_svg += symbol;
			out_svg += "\n";
		}
		out_svg += "</svg>";


		// Write output to either file or stdout
		File outfile;
		FileOutputStream ostream;

		if (outfile_path != null) {
			// Create output file
			try {
				outfile = File.new_for_path(outfile_path);
				ostream = outfile.replace(null, false, 0, null);
			}
			catch (Error e) {
				stderr.printf ("Failed to create output file: %s", e.message);
				return false;
			}

			// Write data (in chunks)
			try {
				uint8[] data = out_svg.data;
				long written = 0;
				while (written < data.length) {
					written += ostream.write(data[written:data.length]);
				}
			}
			catch (IOError e) {
				stderr.printf ("Failed to write to output file: %s", e.message);
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


#include <convert.hpp>

#include <kdb.hpp>
#include <modules.hpp>
#include <cmdline.hpp>
#include <print.hpp>

#include <iostream>
#include <memory>

using namespace kdb;
using namespace std;

ConvertCommand::ConvertCommand()
{}

int ConvertCommand::execute(Cmdline const& cl)
{
	size_t argc = cl.arguments.size();
	if (argc != 0 && argc != 1 && argc != 2 && argc != 3 && argc != 4)
	{
		throw invalid_argument("need 0 to 4 arguments");
	}

	string import_format = "dump";
	if (argc > 0) import_format = cl.arguments[0];

	string export_format = "dump";
	if (argc > 1) export_format = cl.arguments[1];

	string import_file = "/dev/stdin";
	if (argc > 2 && cl.arguments[2] != "-") import_file = cl.arguments[2];

	string export_file = "/dev/stdout";
	if (argc > 3 && cl.arguments[3] != "-") export_file = cl.arguments[3];

	if (cl.verbose)
	{
		cout << "converting from " << import_format
		     << " to " << export_format << endl;
	}

	Modules modules;
	auto_ptr<Plugin> import_plugin = modules.load(import_format);
	auto_ptr<Plugin> export_plugin = modules.load(export_format);

	Key errorKey;
	KeySet keys;

	errorKey.setString(import_file);
	import_plugin->get(keys, errorKey);

	errorKey.setString(export_file);
	export_plugin->set(keys, errorKey);

	printError(errorKey);
	printWarnings(errorKey);

	return 0;
}

ConvertCommand::~ConvertCommand()
{}

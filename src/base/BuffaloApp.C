#include "BuffaloApp.h"
#include "Moose.h"
#include "AppFactory.h"
#include "ModulesApp.h"
#include "MooseSyntax.h"

template <>
InputParameters
validParams<BuffaloApp>()
{
  InputParameters params = validParams<MooseApp>();
  return params;
}

BuffaloApp::BuffaloApp(InputParameters parameters) : MooseApp(parameters)
{
  Moose::registerObjects(_factory);
  ModulesApp::registerObjects(_factory);
  BuffaloApp::registerObjects(_factory);

  Moose::associateSyntax(_syntax, _action_factory);
  ModulesApp::associateSyntax(_syntax, _action_factory);
  BuffaloApp::associateSyntax(_syntax, _action_factory);
}

BuffaloApp::~BuffaloApp() {}

// External entry point for dynamic application loading
extern "C" void
BuffaloApp__registerApps()
{
  BuffaloApp::registerApps();
}
void
BuffaloApp::registerApps()
{
  registerApp(BuffaloApp);
}

// External entry point for dynamic object registration
extern "C" void
BuffaloApp__registerObjects(Factory & factory)
{
  BuffaloApp::registerObjects(factory);
}
void
BuffaloApp::registerObjects(Factory & factory)
{
}

// External entry point for dynamic syntax association
extern "C" void
BuffaloApp__associateSyntax(Syntax & syntax, ActionFactory & action_factory)
{
  BuffaloApp::associateSyntax(syntax, action_factory);
}
void
BuffaloApp::associateSyntax(Syntax & /*syntax*/, ActionFactory & /*action_factory*/)
{
}

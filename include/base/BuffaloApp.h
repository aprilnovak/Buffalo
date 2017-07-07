#ifndef BUFFALOAPP_H
#define BUFFALOAPP_H

#include "MooseApp.h"

class BuffaloApp;

template <>
InputParameters validParams<BuffaloApp>();

class BuffaloApp : public MooseApp
{
public:
  BuffaloApp(InputParameters parameters);
  virtual ~BuffaloApp();

  static void registerApps();
  static void registerObjects(Factory & factory);
  static void associateSyntax(Syntax & syntax, ActionFactory & action_factory);
};

#endif /* BUFFALOAPP_H */

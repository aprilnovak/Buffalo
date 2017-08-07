#ifndef KAPPAFISSIONTOHEATSOURCE_H
#define KAPPAFISSIONTOHEATSOURCE_H

#include "AuxKernel.h"

class KappaFissionToHeatSource;

template<>
InputParameters validParams<KappaFissionToHeatSource>();

class KappaFissionToHeatSource : public AuxKernel
{
public:
  KappaFissionToHeatSource(const InputParameters & parameters);

  virtual ~KappaFissionToHeatSource();

protected:
  virtual Real computeValue();
  const VariableValue & _kappa_fission;
  const Real & _power;
  const bool & _one_group_PKE;
  std::vector<VariableValue *> _keff;
  const PostprocessorValue & _volume_pp;
};

#endif //KAPPAFISSIONTOHEATSOURCE_H
